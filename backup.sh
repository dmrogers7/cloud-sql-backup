#!/bin/bash

die() { echo "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

create_new_backup() {
	STATUS="UNDEFINED"
	ATTEMPT=1

	while [[ ${ATTEMPT} -le ${MAX_ATTEMPTS} && "${STATUS}" != "SUCCESSFUL" ]]
	do
		if [[ ${ATTEMPT} -gt 1 ]]; then
			echo "Waiting ${WAIT_SECONDS} seconds before retrying ..."
			sleep ${WAIT_SECONDS}
		fi

		echo "Attempt number ${ATTEMPT}"
		ATTEMPT=`expr ${ATTEMPT} + 1`
		DESCRIPTION="On Demand Scheduled Backup: `date +'%Y-%m-%d %H:%M'`"

		echo "Submitting backup ..."
		gcloud sql backups create --async --instance ${INSTANCE_ID} --description="${DESCRIPTION}"

		if [[ $? -ne 0 ]]; then
			echo "WARN: Submit backup job failed!"
			continue
		fi

		JOB_NAME=$(gcloud sql operations list --instance ${INSTANCE_ID} --filter="operationType='BACKUP_VOLUME' AND status!='DONE'" --format="value(name)")
		gcloud sql operations wait "${JOB_NAME}" --timeout=unlimited

		if [[ $? -ne 0 ]]; then
			echo "WARN: Create backup job failed!"
			continue
		fi

		STATUS=$(gcloud sql backups list --instance ${INSTANCE_ID} --filter="type='ON_DEMAND' AND description='${DESCRIPTION}'" --format="value(status)" --limit=1)
		
		if [[ "${STATUS}" != "SUCCESSFUL" ]]; then
			echo "WARN: Backup was not successful, status = ${STATUS}"
		fi
	done

	if [[ "${STATUS}" == "SUCCESSFUL" ]]; then
		echo "Backup successful"
	else
		die "ERROR: Exhausted all attempts to backup instance ${INSTANCE_ID}"
	fi
}

delete_old_backups() {
	echo "Listing all On Demand Scheduled Backups"
	gcloud sql backups list --instance ${INSTANCE_ID} --sort-by="~startTime" --filter="type='ON_DEMAND' AND description~'On Demand' AND status!='RUNNING'" --format="table[box](id, type, status, startTime, endTime, description)"

	LINE_NUMBER=`expr ${BACKUPS_TO_KEEP} + 1`
	BACKUP_IDS=`gcloud sql backups list --instance ${INSTANCE_ID} --sort-by="~startTime" --filter="type='ON_DEMAND' AND description~'On Demand' AND status!='RUNNING'" --format="value(id)" | tail -n +${LINE_NUMBER} | cut -f 1`

	if [[ -n "${BACKUP_IDS}" ]]; then
		echo "Number of backups to keep: ${BACKUPS_TO_KEEP}, deleting extras ..."
		for BACKUP_ID in `echo "${BACKUP_IDS}"`
		do
			gcloud sql backups delete ${BACKUP_ID} --instance ${INSTANCE_ID} --quiet

			if [[ $? -ne 0 ]]; then
				echo "WARN: Delete of backup ID ${BACKUP_ID} failed"
			fi
		done
	fi
}

# --------------------------------------------------------
# Main
# --------------------------------------------------------
need "gcloud"

if [[ -z "${INSTANCE_ID}" ]]; then
	die "Environment variable INSTANCE_ID is required"
fi
BACKUPS_TO_KEEP=${BACKUPS_TO_KEEP-24}
MAX_ATTEMPTS=${MAX_ATTEMPTS-3}
WAIT_SECONDS=${WAIT_SECONDS-300}

create_new_backup
delete_old_backups
