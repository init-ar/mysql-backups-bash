#!/bin/bash
set -o pipefail

# Ruta del archivo de configuración.
# Puedes ajustar la ruta si lo deseas, por ejemplo: /etc/backup_script.conf
CONFIG_FILE="$(dirname "$0")/mysql-databases.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Ruta del archivo de funciones
FUNCTIONS_FILE="$(dirname "$0")/functions.sh"
source "$FUNCTIONS_FILE"

# Asignar valores por defecto en caso de que no se hayan definido en el archivo de configuración.
: ${DB_USER:="default_user"}
: ${DB_PASS:="default_pass"}
: ${MYSQL_HOST:=""}  # Nuevo: Host remoto de MySQL (vacío = localhost)
: ${DEFAULT_CLOUD_BUCKET:="gs://bucket-backups-servers/databases"}
: ${CLOUD_BUCKET:="$DEFAULT_CLOUD_BUCKET"}
: ${LOCAL_PATH:="/var/backups/databases"}
: ${REMOTE_HOST:=""}
: ${RETENTION_DAYS:=7}
: ${ENCRYPTION_KEY:=""}
: ${MODE:="gcp"}
: ${K8S_POD:=""}
: ${K8S_NAMESPACE:="default"}

LOG_FILE="/var/log/backups-databases.log"
BACKUP_DATE=$(date +%Y%m%d-%H%M)
ERROR_COUNT=0

# Process command line options
while getopts "m:l:b:k:T:h:P:N:H:" opt; do  # Añadido :H para el host MySQL
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
        P)
            K8S_POD=$OPTARG
            ;;
        N)
            K8S_NAMESPACE=$OPTARG
            ;;
        H)  # Nuevo parámetro para host MySQL remoto
            MYSQL_HOST=$OPTARG
            ;;
        *)
cat << 'EOF'
Usage: $0 [options]

Options:
  -m  Mode of backup. Valid options:
         gcp   -> Backup to a Google Cloud Storage bucket.
         local -> Backup to a local folder.
         s3    -> Backup to an AWS S3 bucket.
         k8s   -> Backup from a Kubernetes pod (using port-forward).
         
  -l  Backup path:
         For 'local' mode, this is the destination folder on the local system.
         For remote transfers (when using -h), this is the folder on the remote host.
         
  -b  Cloud bucket path (for gcp and s3 modes). Example:
         gs://my-bucket/path or s3://my-bucket/path
         
  -k  Encryption key to encrypt the backup using AES-256-CBC.
  
  -T  Retention days: number of days to keep backup files.
  
  -h  Remote host for transferring backups (format: user@host).
  
  -H  MySQL host (remote server to connect to for backups).
  
  -P  Kubernetes pod name (required for k8s mode).
  
  -N  Kubernetes namespace (optional for k8s mode; default is 'default').

Examples:
  $0 -m local -l /backups/mysql -T 7
  $0 -m gcp -b gs://my-bucket/path -k mysecret
  $0 -m k8s -P my-mysql-pod -N my-namespace -l /backups/mysql
  $0 -m local -l /backups/mysql -h user@remotehost
  $0 -m local -l /backups/mysql -H mysql-remote.example.com  # Backup remoto

EOF
exit 1
;;
    esac
done
shift $((OPTIND - 1))

# Main function to orchestrate the backup process
main() {
    # ADD: llamadas no intrusivas
    init_mysql_endpoint
    [ "$MODE" != "k8s" ] && test_mysql_connection

    local db_names=($(get_mysql_db_names))
    for db in "${db_names[@]}"; do
        backup_mysql_database "$db"
    done

    # Apply retention policy if in local or k8s mode
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
