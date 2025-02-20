#!/bin/bash

# Global variables
DB_USER="user_backups"
DB_PASS="$PASSWD" 
BUCKET_NAME="gs://bucket-backups-servers/databases"
LOG_FILE="/var/log/backups/bkp-databases.log"
BACKUP_DATE=$(date +%Y%m%d)
ERROR_COUNT=0

# Default mode is "gcp"
MODE="gcp"
# Default local path (change as needed)
LOCAL_PATH="/var/backups/databases"

# Process command line options
while getopts "m:l:" opt; do
    case $opt in
        m)
            MODE=$OPTARG
            ;;
        l)
            LOCAL_PATH=$OPTARG
            ;;
        *)
            echo "Usage: $0 [-m mode (gcp|local)] [-l local_backup_path]"
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Logging function with error checking
log_check_message() {
    echo "$1 on $(date)" >> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        echo "[error] An error occurred during $1" >> "$LOG_FILE"
        exit 1
    fi
}

# Function to get the list of databases (excluding system databases)
get_db_names() {
    log_check_message "[info] Starting to retrieve databases"
    local excluded="information_schema performance_schema sys"
    local dbs=()
    local all_dbs

    all_dbs=$(mysql -u"$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
    if [ $? -ne 0 ]; then
        log_check_message "[error] Error retrieving databases"
        exit 1
    fi

    for db in $all_dbs; do
        local skip=0
        for e in $excluded; do
            if [ "$db" == "$e" ]; then
                skip=1
                break
            fi
        done
        if [ $skip -eq 0 ]; then
            dbs+=("$db")
        fi
    done

    log_check_message "[info] Retrieved databases: ${dbs[*]}"
    echo "${dbs[@]}"
}

# Function to perform backup for a single database
backup_database() {
    local db_name="$1"
    local file_name="${db_name}_${BACKUP_DATE}.sql.gz"

    log_check_message "[info] Starting backup for ${db_name}"

    if [ "$MODE" == "local" ]; then
        # Local backup: store file in LOCAL_PATH
        local backup_file="${LOCAL_PATH}/${db_name}/${file_name}"
        mkdir -p "${LOCAL_PATH}/${db_name}"  # Ensure directory exists
        mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip > "$backup_file"
        if [ $? -ne 0 ]; then
            log_check_message "[error] Error during local backup for ${db_name}"
            ((ERROR_COUNT++))
        else
            log_check_message "[info] Local backup for ${db_name} completed: ${backup_file}"
        fi
    else
        # GCP backup: use gsutil to copy backup directly to the bucket
        local remote_file="${db_name}/${file_name}"
        mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip | gsutil cp - "${BUCKET_NAME}/${remote_file}"
        if [ $? -ne 0 ]; then
            log_check_message "[error] Error during GCP backup for ${db_name}"
            ((ERROR_COUNT++))
        else
            log_check_message "[info] GCP backup for ${db_name} completed: ${remote_file}"
        fi
    fi
}

# Main function to orchestrate the backup process
main() {
    local db_names=($(get_db_names))
    for db in "${db_names[@]}"; do
        backup_database "$db"
    done

    if [ $ERROR_COUNT -gt 0 ]; then
        log_check_message "[error] Process completed with ${ERROR_COUNT} errors"
        exit 1
    else
        log_check_message "[info] All backups completed successfully"
        exit 0
    fi
}

# Execute the script
main

