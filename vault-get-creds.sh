#!/bin/sh

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

need_var() {
    if [ -z "$1" ]; then
        die "$2 needed to continue"
    fi 
}

need() {
    which "$1" &>/dev/null || install_dependency "$1" || die "Binary '$1' is missing but required"
}

need "curl"
need "vault"
need "jq"

need_var "$APPROLE_ID" "APPROLE_ID"
need_var "$APPROLE_SECRET_ID" "APPROLE_SECRET_ID"
need_var "$VAULT_ADDR" "VAULT_ADDR"
need_var "$VAULT_SERVICE_ACCOUNT_PATH" "VAULT_SERVICE_ACCOUNT_PATH"
need_var "$VAULT_SERVICE_ACCOUNT" "VAULT_SERVICE_ACCOUNT"
need_var "$VAULT_SERVICE_ACCOUNT_FIELD" "VAULT_SERVICE_ACCOUNT_FIELD"
need_var "$SERVICE_ACCOUNT_JSON_CREDS_PATH" "SERVICE_ACCOUNT_JSON_CREDS_PATH"

log_message "Retrieving token from vault"
VAULT_TOKEN=$(curl -s --request POST --data '{"role_id":"'"$APPROLE_ID"'","secret_id":"'"$APPROLE_SECRET_ID"'"}' "$VAULT_ADDR"/v1/auth/approle/login | jq -r '.auth.client_token')

need_var "$VAULT_TOKEN" "VAULT_TOKEN"

log_message "Logging into vault to retrieve creds"
vault login "$VAULT_TOKEN"

log_message "Downloading service acct creds"
vault read -field "$VAULT_SERVICE_ACCOUNT_FIELD" secret/"$VAULT_SERVICE_ACCOUNT_PATH/$VAULT_SERVICE_ACCOUNT" > "$SERVICE_ACCOUNT_JSON_CREDS_PATH"
