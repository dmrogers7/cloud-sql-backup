# cloud-sql-backup

Perform on-demand backups of a Google Cloud SQL instance.

Google provides the ability to schedule an automated backup once a day, if you require more frequent backups, then you must do it yourself, which is where `cloud-sql-backup` comes into play.

_Note:_ `cloud-sql-backup` does not provide the scheduling mechanism itself, instead that should be handled by the platform in which it executes.  For instance, if running on a Unix server, then [cron](https://en.wikipedia.org/wiki/Cron) may be appropriate choice.  If running in Kubernetes, then a [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) could be used.

## Features

* Retries - On-demand backups are operations on a Cloud SQL instance and only one operation can be running at a time.  `cloud-sql-backup` has a configurble retry capability to wait for an in-progress operation to finish

* Clean Up - Unlike automated backups, on-demand backups are billed for their storage requirements.  `cloud-sql-backup` retains only the last 'X' backups and will delete any extras.

## Requirements

`cloud-sql-backup` relies on this software, which is expected to be provided by the underlying system in which it runs

* bash
* gcloud

## Environment Variables

`cloud-sql-backup` is configurable through the use of these environment variables:

| Variable Name                     | Default Value | Description |
| :-----------:                     | :-----------: | :---------- | 
| `SERVICE_ACCOUNT_JSON_CREDS_PATH` | None          | The location of the file containing the service account credentials in JSON format
| `INSTANCE_ID`                     | None          | The ID of the cloud sql instance to backup |
| `BACKUPS_TO_KEEP`                 | 24            | The number of backups to retain |
| `MAX_ATTEMPTS`                    | 3             | The number of attempts to try to create a successful backup
| `WAIT_SECONDS`                    | 300           | The number of seconds to wait at a failed attempt before retrying

## Usage

At a minimum the `SERVICE_ACCOUNT_JSON_CREDS_PATH` and `INSTANCE_ID` variables must be provided, like:

```
SERVICE_ACCOUNT_JSON_CREDS_PATH=/tmp/my-creds.json INSTANCE_ID=my-sql-instance ./backup.sh
```

To try just once and only keep the last backup, call like this:

```
export SERVICE_ACCOUNT_JSON_CREDS_PATH=/tmp/creds.json
export INSTANCE_ID=my-sql-instance
export MAX_ATTEMPTS=1
export WAIT_SECONDS=0
export BACKUPS_TO_KEEP=1
./backup.sh
```

## Authorization

The service account must have these permissions

| Command                     | Required permissions |
| :-------------------------- | :------------------- |
| gcloud sql backups create   | cloudsql.backupRuns.create |
| gcloud sql backups delete   | cloudsql.backupRuns.delete |
| gcloud sql backups list     | cloudsql.backupRuns.list |
| gcloud sql operations list  | cloudsql.instances.get |
| gcloud sql operations wait  | cloudsql.instances.get | 

You can grant the service account each of the above permissions or use one of the predefined roles that has all the required permissions (and many more)

* Cloud SQL Admin
* Editor
* Owner

# Docker

The provided [Dockerfile](./Dockerfile) can be used to generate a docker image to run locally, like this:

```
docker build --tag cloud-sql-backup:local .
docker run --rm --env SERVICE_ACCOUNT_JSON_CREDS_PATH=/tmp/creds.json --env INSTANCE_ID=my-sql-instance cloud-sql-backup:local
```
