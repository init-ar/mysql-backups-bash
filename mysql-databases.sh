#!/bin/bash
set -o pipefail

# Ruta del archivo de configuración.
CONFIG_FILE="$(dirname "$0")/mysql-databases.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Valores por defecto
: ${DB_USER:="default_user"}
: ${DB_PASS:="default_pass"}
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

# Opciones de línea de comando
while getopts "m:l:b:k:T:h:P:N:" opt; do
  case $opt in
    m) MODE=$OPTARG ;;
    l) LOCAL_PATH=$OPTARG ;;
    b) CLOUD_BUCKET=$OPTARG ;;
    k) ENCRYPTION_KEY=$OPTARG ;;
    T) RETENTION_DAYS=$OPTARG ;;
    h) REMOTE_HOST=$OPTARG ;;
    P) K8S_POD=$OPTARG ;;
    N) K8S_NAMESPACE=$OPTARG ;;
    *) 
      cat << 'EOF'
Usage: $0 [options]
  -m  modo: gcp, local, s3, k8s
  -l  ruta local
  -b  bucket (gs:// o s3://)
  -k  passphrase para GPG
  -T  días de retención
  -h  user@host remoto
  -P  pod k8s
  -N  namespace k8s
EOF
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

log_check_message() {
  local ts=$(date '+%a %b %e %T %Y')
  echo "[${ts}] $1" >> "$LOG_FILE"
  [[ $? -ne 0 ]] && { echo "[${ts}] [error] Logging failed: $1" >> "$LOG_FILE"; exit 1; }
}

get_db_names() {
  log_check_message "[info] Listando bases de datos"
  local excluded="information_schema performance_schema sys"
  local all_dbs=$(mysql -u"$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
  [[ $? -ne 0 ]] && { log_check_message "[error] No se pudo listar DBs"; exit 1; }
  for db in $all_dbs; do
    [[ " $excluded " =~ " $db " ]] || dbs+=("$db")
  done
  log_check_message "[info] Bases obtenidas: ${dbs[*]}"
  echo "${dbs[@]}"
}

encrypt_with_gpg() {
  # $1: fichero de entrada stdin, $2: fichero de salida
  gpg --batch --yes \
      --passphrase "$ENCRYPTION_KEY" \
      --symmetric \
      --cipher-algo AES256 \
      --compress-algo none \
      --pinentry-mode loopback \
      --output "$2"
}

backup_database() {
  local db="$1"
  local ext=".sql.gz.gpg"
  local file="${db}-${BACKUP_DATE}${ext}"

  log_check_message "[info] Iniciando backup $db"

  case $MODE in
    local|k8s)
      local tmp="/tmp/${file}"
      mkdir -p "/tmp"
      mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db" 2>/dev/null | gzip | encrypt_with_gpg - "$tmp"
      if [[ $? -ne 0 ]]; then
        log_check_message "[error] Backup fallido $db"
        ((ERROR_COUNT++))
        rm -f "$tmp"
        return 1
      fi

      if [[ -n "$REMOTE_HOST" ]]; then
        log_check_message "[info] Enviando $db a $REMOTE_HOST:$LOCAL_PATH"
        scp "$tmp" "${REMOTE_HOST}:${LOCAL_PATH}/${file}"
      else
        mkdir -p "${LOCAL_PATH}/${db}"
        mv "$tmp" "${LOCAL_PATH}/${db}/${file}"
      fi
      ;;
    s3)
      mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db" | gzip | encrypt_with_gpg - >(aws s3 cp - "${CLOUD_BUCKET}/${db}/${file}")
      ;;
    gcp)
      mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction "$db" | gzip | encrypt_with_gpg - >(gsutil cp - "${CLOUD_BUCKET}/${db}/${file}")
      ;;
    *)
      echo "Modo inválido: $MODE"; exit 1
      ;;
  esac

  [[ $? -ne 0 ]] && { log_check_message "[error] Transferencia $db fallida"; ((ERROR_COUNT++)); } \
                 || log_check_message "[info] Backup $db completado"
}

apply_retention_policy() {
  log_check_message "[info] Aplicando retención $RETENTION_DAYS días"
  if [[ "$MODE" =~ ^(local|k8s)$ ]]; then
    if [[ -n "$REMOTE_HOST" ]]; then
      ssh "$REMOTE_HOST" "find \"$LOCAL_PATH\" -type f -mtime +${RETENTION_DAYS} -delete"
    else
      find "$LOCAL_PATH" -type f -mtime +${RETENTION_DAYS} -delete
    fi
  fi
}

main() {
  for db in $(get_db_names); do
    backup_database "$db"
  done
  apply_retention_policy
  if ((ERROR_COUNT>0)); then
    log_check_message "[error] Finalizado con errores: $ERROR_COUNT"
    exit 1
  else
    log_check_message "[info] Todos los backups OK"
    exit 0
  fi
}

main
