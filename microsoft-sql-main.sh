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

# Ruta del archivo de funciones
FUNCTIONS_FILE="$(dirname "$0")/functions.sh"
source "$FUNCTIONS_FILE"

LOG_FILE="/var/log/backups-databases.log"
BACKUP_DATE=$(date +%Y%m%d-%H%M)
ERROR_COUNT=0

main() {
    local db_names=($(get_mssql_db_names))
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