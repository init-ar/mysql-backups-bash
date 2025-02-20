#!/bin/bash
set -o pipefail

# Global variables
DB_USER="user_backups"
DB_PASS="PASSWD"
DEFAULT_CLOUD_BUCKET="gs://bucket-backups-servers/databases"
CLOUD_BUCKET="$DEFAULT_CLOUD_BUCKET"
LOG_FILE="/var/log/backups-databases.log"
# Timestamp format: YYYYMMDD-hhmm
BACKUP_DATE=$(date +%Y%m%d-%H%M)
ERROR_COUNT=0
ENCRYPTION_KEY=""  # Default: no encryption

# Default mode is "gcp"
MODE="gcp"
# Default backup path for local backups.
# For local mode, this is the local folder.
# For remote mode, this is the destination folder on the remote host.
LOCAL_PATH="/var/backups/databases"
# Remote host (user@host). If empty, backups are stored locally.
REMOTE_HOST=""
# Default retention days (applies for local mode)
RETENTION_DAYS=7

# Process command line options
while getopts "m:l:b:k:T:h:" opt; do
    case $opt in
        m)
            MODE=$OPTARG
            ;;
        l)
            LOCAL_PATH=$OPTARG
            ;;
        b)
            CLOUD_BUCKET=$OPTARG
            ;;
        k)
            ENCRYPTION_KEY=$OPTARG
            ;;
        T)
            RETENTION_DAYS=$OPTARG
            ;;
        h)
            REMOTE_HOST=$OPTARG
            ;;
        *)
            echo "Usage: $0 [-m mode (gcp|local|s3)] [-l backup_path] [-b cloud_bucket_path] [-k encryption_key] [-T retention_days] [-h remote_host (user@host)]"
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Logging function with formatted timestamp and error checking
log_check_message() {
    local timestamp
    timestamp=$(date '+%a %b %e %T %Y')
    local log_message="[${timestamp}] $1"
    echo "$log_message" >> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        echo "[${timestamp}] [error] An error occurred during logging: $1" >> "$LOG_FILE"
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
    local ext=".sql.gz"
    if [ -n "$ENCRYPTION_KEY" ]; then
        ext=".sql.gz.enc"
    fi
    local file_name="${db_name}-${BACKUP_DATE}${ext}"
    
    log_check_message "[info] Starting backup for ${db_name}"
    
    if [ "$MODE" == "local" ]; then
        if [ -n "$REMOTE_HOST" ]; then
            # Remote backup via SSH:
            # Create backup in a temporary local file and then transfer via scp.
            local tmp_backup="/tmp/${file_name}"
            if [ -n "$ENCRYPTION_KEY" ]; then
                mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip | \
                openssl enc -aes-256-cbc -salt -pass pass:"$ENCRYPTION_KEY" > "$tmp_backup"
            else
                mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip > "$tmp_backup"
            fi
            if [ $? -ne 0 ]; then
                log_check_message "[error] Error during backup for ${db_name} (creating temporary file)"
                ERROR_COUNT=$((ERROR_COUNT+1))
                rm -f "$tmp_backup"
                return 1
            fi
            log_check_message "[info] Transferring backup for ${db_name} to remote host ${REMOTE_HOST}:${LOCAL_PATH}"
            scp "$tmp_backup" "${REMOTE_HOST}:${LOCAL_PATH}/${db_name}-${BACKUP_DATE}${ext}"
            if [ $? -ne 0 ]; then
                log_check_message "[error] Failed to transfer backup for ${db_name} to remote host"
                ERROR_COUNT=$((ERROR_COUNT+1))
            else
                log_check_message "[info] Successfully transferred backup for ${db_name} to remote host"
            fi
            rm -f "$tmp_backup"
        else
            # Local backup to local filesystem
            local backup_dir="${LOCAL_PATH}/${db_name}"
            mkdir -p "$backup_dir"
            local backup_file="${backup_dir}/${file_name}"
            if [ -n "$ENCRYPTION_KEY" ]; then
                mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip | \
                openssl enc -aes-256-cbc -salt -pass pass:"$ENCRYPTION_KEY" > "$backup_file"
            else
                mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip > "$backup_file"
            fi
            if [ $? -ne 0 ]; then
                log_check_message "[error] Error during local backup for ${db_name}"
                ERROR_COUNT=$((ERROR_COUNT+1))
            else
                log_check_message "[info] Local backup for ${db_name} completed: ${backup_file}"
            fi
        fi
    elif [ "$MODE" == "s3" ]; then
        # S3 backup: use AWS CLI to copy to the bucket defined in CLOUD_BUCKET
        local remote_file="${db_name}/${file_name}"
        if [ -n "$ENCRYPTION_KEY" ]; then
            mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip | \
            openssl enc -aes-256-cbc -salt -pass pass:"$ENCRYPTION_KEY" | aws s3 cp - "${CLOUD_BUCKET}/${remote_file}"
        else
            mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip | aws s3 cp - "${CLOUD_BUCKET}/${remote_file}"
        fi
        if [ $? -ne 0 ]; then
            log_check_message "[error] Error during S3 backup for ${db_name}"
            ERROR_COUNT=$((ERROR_COUNT+1))
        else
            log_check_message "[info] S3 backup for ${db_name} completed: ${remote_file}"
        fi
    elif [ "$MODE" == "gcp" ]; then
        # GCP backup: use gsutil to copy to the bucket defined in CLOUD_BUCKET
        local remote_file="${db_name}/${file_name}"
        if [ -n "$ENCRYPTION_KEY" ]; then
            mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip | \
            openssl enc -aes-256-cbc -salt -pass pass:"$ENCRYPTION_KEY" | gsutil cp - "${CLOUD_BUCKET}/${remote_file}"
        else
            mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db_name" | gzip | gsutil cp - "${CLOUD_BUCKET}/${remote_file}"
        fi
        if [ $? -ne 0 ]; then
            log_check_message "[error] Error during GCP backup for ${db_name}"
            ERROR_COUNT=$((ERROR_COUNT+1))
        else
            log_check_message "[info] GCP backup for ${db_name} completed: ${remote_file}"
        fi
    else
        echo "Unknown mode: $MODE. Valid modes: gcp, local, s3"
        exit 1
    fi
}

# Function to apply retention policy for local backups
apply_retention_policy() {
    log_check_message "[info] Applying retention policy: deleting backups older than ${RETENTION_DAYS} days."
    if [ "$MODE" == "local" ]; then
        if [ -n "$REMOTE_HOST" ]; then
            # Remote retention: use SSH to delete old backups in the remote path
            ssh "$REMOTE_HOST" "find \"$LOCAL_PATH\" -type f -mtime +${RETENTION_DAYS} -delete"
            if [ $? -eq 0 ]; then
                log_check_message "[info] Retention policy applied successfully on remote destination."
            else
                log_check_message "[error] Failed to apply retention policy on remote destination."
            fi
        else
            find "$LOCAL_PATH" -type f -mtime +${RETENTION_DAYS} -delete
            if [ $? -eq 0 ]; then
                log_check_message "[info] Retention policy applied successfully on local destination."
            else
                log_check_message "[error] Failed to apply retention policy on local destination."
            fi
        fi
    else
        log_check_message "[info] Retention policy not applied for mode ${MODE}."
    fi
}

# Main function to orchestrate the backup process
main() {
    local db_names=($(get_db_names))
    for db in "${db_names[@]}"; do
        backup_database "$db"
    done

    # Apply retention policy if in local mode
    apply_retention_policy

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
