#!/bin/bash
set -o pipefail

# Configurar PATH para incluir sqlcmd
export PATH="/opt/mssql-tools/bin:$PATH"

# Ruta del archivo de configuración.
# Puedes ajustar la ruta si lo deseas, por ejemplo: /etc/backup_script.conf
CONFIG_FILE="$(dirname "$0")/mssql.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

LOG_FILE="/var/log/backups-databases.log"
BACKUP_DATE=$(date +%Y%m%d-%H%M)
ERROR_COUNT=0

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

get_db_names() {
    log_check_message "[info] Starting to retrieve databases"
    local sqlcmd_cmd="sqlcmd"

    [ -n "$MSSQL_HOST" ] && sqlcmd_cmd+=" -S $MSSQL_HOST"

    local dbs=$($sqlcmd_cmd -U "$DB_USER" -P "$DB_PASS" -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE state = 0 AND name NOT IN ($EXCLUDED_DBS)" -h -1 2>/dev/null | grep -v '^$')

    if [ $? -ne 0 ] || [ -z "$dbs" ]; then
        log_check_message "[error] Error retrieving databases"
        exit 1
    fi

    log_check_message "[info] Retrieved databases: $dbs"
    printf '%s\n' $dbs
}

backup_mssql_database() {
    local db_name="$1"
    
    local file_name="${db_name}-${BACKUP_DATE}.bak"

    local dump_cmd="sqlcmd"
    
    log_check_message "[info] Starting backup for ${db_name}"
    
    # Comando base para mysqldump + compresión
    # Construir el comando de backup paso a paso

    dump_cmd+=" -S \"$MSSQL_HOST\""
    dump_cmd+=" -U \"$DB_USER\""
    dump_cmd+=" -P \"$DB_PASS\""
    dump_cmd+=" -Q \"BACKUP DATABASE [$db_name] TO DISK = '${MAPPED_DRIVE}\\${file_name}' WITH COMPRESSION, STATS=10\""

    eval "$dump_cmd" && \
    log_check_message "[info] Local backup succeeded: ${db_name}" || \
    log_check_message "[error] Local backup failed: ${db_name}"

    local copy_dump="cp ${LOCAL_TMP_DUMP_PATH}/${file_name} ${LOCAL_PATH}"

    eval "$copy_dump" && \
    log_check_message "[info] Local copy succeeded: ${db_name}" || \
    log_check_message "[error] Local copy failed: ${db_name}"

    local delete_dump="rm ${LOCAL_TMP_DUMP_PATH}/${file_name}"

    eval "$delete_dump" && \
    log_check_message "[info] Succesfully deleted: ${db_name}" || \
    log_check_message "[error] Delete failed: ${db_name}"

}

# Function to apply retention policy for local backups (and k8s backups stored locally)
apply_retention_policy() {
    log_check_message "[info] Applying retention policy: deleting backups older than ${RETENTION_DAYS} days."

    find "$LOCAL_PATH" -type f -mtime +${RETENTION_DAYS} -delete
    if [ $? -eq 0 ]; then
        log_check_message "[info] Retention policy applied successfully on local destination ${LOCAL_PATH}."
    else
        log_check_message "[error] Failed to apply retention policy on local destination."
    fi
}


main() {
    local db_names=($(get_db_names))
    for db in "${db_names[@]}"; do
        backup_mssql_database "$db"
   done

   # Apply retention policys
   apply_retention_policy

    if [ $ERROR_COUNT -gt 0 ]; then
        log_check_message "[error] Process completed with ${ERROR_COUNT} errors"
        exit 1
    else
        log_check_message "[info] All backups completed successfully"
        exit 0
    fi
}

#Execute the script
main