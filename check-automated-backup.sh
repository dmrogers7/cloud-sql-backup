#!/bin/bash

log_message() {
    echo ""
    echo "---------------------------------------------------------------------------------"
    echo "$*"
    echo "---------------------------------------------------------------------------------"
    echo ""
}

install_dependency() {
	# TODO make adaptable to multiple OS flavors by parsing the contents of /etc/os-release
	apk add "$1"
}

die() { log_message "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || install_dependency "$1" || die "Binary '$1' is missing but required"
}

check_for_backup() {
	SECONDS_AGO=$((HOURS_AGO * 3600))
	THRESHOLD_TIME=$(date -u -d "@$(($(date +%s) - SECONDS_AGO))" "+%Y-%m-%dT%H")
	log_message "Finding automated backups for ${INSTANCE_ID} newer than ${THRESHOLD_TIME} ..."
	BACKUPS=$(gcloud sql backups list --instance ${INSTANCE_ID} --filter="type='AUTOMATED' AND status='SUCCESSFUL' AND startTime>'${THRESHOLD_TIME}'" --format="table[box](id, type, startTime, status)")
	if [[ -z "${BACKUPS}" ]]; then
		die "No automated backups found!"
	else
		echo "${BACKUPS}"
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

HOURS_AGO=${HOURS_AGO:-28}

gcloud auth activate-service-account --key-file="${SERVICE_ACCOUNT_JSON_CREDS_PATH}"

check_for_backup

log_message "Finished"
