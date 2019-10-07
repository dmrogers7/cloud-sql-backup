#!/bin/bash

log_message() {
    echo ""
    echo "------------------------------------------------"
    echo "$*"
    echo "------------------------------------------------"
    echo ""
}

install_dependency() {
	#TODO make adaptable to multiple OS flavors by parsing the contents of /etc/os-release
	apk add "$1"
}

die() { log_message "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || install_dependency "$1" || die "Binary '$1' is missing but required"
}

create_new_backup() {
	STATUS="UNDEFINED"
	ATTEMPT=1

	while [[ ${ATTEMPT} -le ${MAX_ATTEMPTS} && "${STATUS}" != "SUCCESSFUL" ]]
	do
		if [[ ${ATTEMPT} -gt 1 ]]; then
			log_message "Waiting ${WAIT_SECONDS} seconds before retrying ..."
			sleep ${WAIT_SECONDS}
		fi

		log_message "Attempt number ${ATTEMPT}"
		ATTEMPT=`expr ${ATTEMPT} + 1`
		DESCRIPTION="On Demand Scheduled Backup: `date +'%Y-%m-%d %H:%M'`"

		log_message "Submitting backup ..."
		gcloud sql backups create --async --instance ${INSTANCE_ID} --description="${DESCRIPTION}"

		if [[ $? -ne 0 ]]; then
			log_message "WARN: Submit backup job failed!"
			continue
		fi

		JOB_NAME=$(gcloud sql operations list --instance ${INSTANCE_ID} --filter="operationType='BACKUP_VOLUME' AND status!='DONE'" --format="value(name)")
		gcloud sql operations wait "${JOB_NAME}" --timeout=unlimited

		if [[ $? -ne 0 ]]; then
			log_message "WARN: Create backup job failed!"
			continue
		fi

		STATUS=$(gcloud sql backups list --instance ${INSTANCE_ID} --filter="type='ON_DEMAND' AND description='${DESCRIPTION}'" --format="value(status)" --limit=1)
		
		if [[ "${STATUS}" != "SUCCESSFUL" ]]; then
			log_message "WARN: Backup was not successful, status = ${STATUS}"
		fi
	done

	if [[ "${STATUS}" == "SUCCESSFUL" ]]; then
		log_message "Backup successful"
	else
		die "ERROR: Exhausted all attempts to backup instance ${INSTANCE_ID}"
	fi
}

delete_old_backups() {
	log_message "Listing all On Demand Scheduled Backups"
	gcloud sql backups list --instance ${INSTANCE_ID} --sort-by="~startTime" --filter="type='ON_DEMAND' AND description~'On Demand' AND status!='RUNNING'" --format="table[box](id, type, status, startTime, endTime, description)"

	LINE_NUMBER=`expr ${BACKUPS_TO_KEEP} + 1`
	BACKUP_IDS=`gcloud sql backups list --instance ${INSTANCE_ID} --sort-by="~startTime" --filter="type='ON_DEMAND' AND description~'On Demand' AND status!='RUNNING'" --format="value(id)" | tail -n +${LINE_NUMBER} | cut -f 1`

	if [[ -n "${BACKUP_IDS}" ]]; then
		log_message "Number of backups to keep: ${BACKUPS_TO_KEEP}, deleting extras ..."
		for BACKUP_ID in `log_message "${BACKUP_IDS}"`
		do
			gcloud sql backups delete ${BACKUP_ID} --instance ${INSTANCE_ID} --quiet

			if [[ $? -ne 0 ]]; then
				log_message "WARN: Delete of backup ID ${BACKUP_ID} failed"
			fi
		done
	fi
}

# --------------------------------------------------------
# Main
# --------------------------------------------------------
need "gcloud"

if [[ -z "${INSTANCE_ID}" ]]; then
	die "Environment variable INSTANCE_ID needed to continue"
fi

if [[ -z "${SERVICE_ACCOUNT_JSON_CREDS_PATH}" ]]; then
	die "Environment variable SERVICE_ACCOUNT_JSON_CREDS_PATH needed to continue"
fi

BACKUPS_TO_KEEP=${BACKUPS_TO_KEEP:-24}
MAX_ATTEMPTS=${MAX_ATTEMPTS:-3}
WAIT_SECONDS=${WAIT_SECONDS:-300}

gcloud auth activate-service-account --key-file="${SERVICE_ACCOUNT_JSON_CREDS_PATH}"

create_new_backup
delete_old_backups
