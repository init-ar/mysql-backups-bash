### Common functions ###

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

# Function to apply retention policy for local backups (and k8s backups stored locally)
apply_retention_policy() {
    log_check_message "[info] Applying retention policy: deleting backups older than ${RETENTION_DAYS} days."
    if [ "$MODE" == "local" ] || [ "$MODE" == "k8s" ]; then
        if [ -n "$REMOTE_HOST" ]; then
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

### MySQL Functions ###

# --- ADD: funciones encapsuladas para endpoint y verificación ---
init_mysql_endpoint() {
    # Informa qué se va a usar
    if [ -n "$MYSQL_HOST" ] && [ "$MODE" != "k8s" ]; then
        log_check_message "[info] Using remote MySQL host: ${MYSQL_HOST}"
    else
        log_check_message "[info] Using local MySQL (no -h)"
    fi
}

test_mysql_connection() {
    # Prueba conexión antes de dumpear
    local mysql_cmd="mysql"
    if [ -n "$MYSQL_HOST" ] && [ "$MODE" != "k8s" ]; then
        mysql_cmd+=" -h ${MYSQL_HOST}"
    fi
    log_check_message "[info] Testing MySQL connectivity"
    ${mysql_cmd} -u"${DB_USER}" -p"${DB_PASS}" -e "SELECT 1;" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_check_message "[error] Unable to connect to MySQL endpoint. Check host/creds/network."
        exit 1
    fi
    log_check_message "[info] MySQL connectivity OK"
}

# Function to get the list of databases (excluding system databases)
get_mysql_db_names_mysql() {
    log_check_message "[info] Starting to retrieve databases"
    local excluded="information_schema performance_schema sys"
    local dbs=()
    local all_dbs
    local mysql_cmd="mysql"
    
    # Añadir host remoto si está definido
    [ -n "$MYSQL_HOST" ] && mysql_cmd+=" -h $MYSQL_HOST"
    
    all_dbs=$($mysql_cmd -u"$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
    if [ $? -ne 0 ]; then
        log_check_message "[error] Error retrieving databases. Check MySQL host connectivity"
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
backup_mysql_database() {
    local db_name="$1"
    local ext=".sql.gz"  # Extensión base
    local gpg_ext=".gpg"
    local full_ext="${ext}"
    
    # Definir extensión basada en encriptación
    if [ -n "$ENCRYPTION_KEY" ]; then
        full_ext="${ext}${gpg_ext}"
    fi
    
    local file_name="${db_name}-${BACKUP_DATE}${full_ext}"
    
    log_check_message "[info] Starting backup for ${db_name}"
    
    # Comando base para mysqldump + compresión
    local dump_cmd="mysqldump"
    # Añadir host remoto si está definido (excepto en modo k8s)
    [ -n "$MYSQL_HOST" ] && [ "$MODE" != "k8s" ] && dump_cmd+=" -h $MYSQL_HOST"
    
    dump_cmd+=" -u\"$DB_USER\" -p\"$DB_PASS\" --single-transaction \"$db_name\" | gzip"
    
    # Añadir encriptación GPG si hay clave
    if [ -n "$ENCRYPTION_KEY" ]; then
        dump_cmd+=" | gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase \"$ENCRYPTION_KEY\""
    fi

    case "$MODE" in
        "local")
            # Modo local o remoto SSH
            if [ -n "$REMOTE_HOST" ]; then
                local tmp_backup="/tmp/${file_name}"
                eval "$dump_cmd" > "$tmp_backup"
                if [ $? -ne 0 ]; then
                    log_check_message "[error] Error during backup for ${db_name}"
                    ERROR_COUNT=$((ERROR_COUNT+1))
                    rm -f "$tmp_backup"
                    return 1
                fi
                scp "$tmp_backup" "${REMOTE_HOST}:${LOCAL_PATH}/${file_name}" && \
                log_check_message "[info] Transferred backup for ${db_name}" || \
                log_check_message "[error] Transfer failed for ${db_name}"
                rm -f "$tmp_backup"
            else
                mkdir -p "${LOCAL_PATH}/${db_name}"
                if eval "$dump_cmd" > "${LOCAL_PATH}/${db_name}/${file_name}"; then
                    log_check_message "[info] Local backup succeeded: ${db_name}"
                else
                    log_check_message "[error] Local backup failed: ${db_name}"
                    ERROR_COUNT=$((ERROR_COUNT+1))
                fi
            fi
            ;;

        "s3"|"gcp")
            # Modos en la nube
            local remote_file="${db_name}/${file_name}"
            if [ "$MODE" == "s3" ]; then
                cloud_cmd="aws s3 cp - \"${CLOUD_BUCKET}/${remote_file}\""
            else
                cloud_cmd="gsutil cp - \"${CLOUD_BUCKET}/${remote_file}\""
            fi
            eval "$dump_cmd | $cloud_cmd" && \
            log_check_message "[info] ${MODE^^} backup succeeded: ${db_name}" || \
            log_check_message "[error] ${MODE^^} backup failed: ${db_name}"
            ;;

        "k8s")
            # Modo Kubernetes (usa port-forwarding local, ignora MYSQL_HOST)
            kubectl port-forward "$K8S_POD" -n "$K8S_NAMESPACE" 3307:3306 &
            PF_PID=$!
            sleep 5
            local tmp_backup="/tmp/${file_name}"
            eval "mysqldump -h 127.0.0.1 -P 3307 -u\"$DB_USER\" -p\"$DB_PASS\" --single-transaction \"$db_name\" | gzip" > "$tmp_backup"
            kill $PF_PID
            if [ -n "$REMOTE_HOST" ]; then
                scp "$tmp_backup" "${REMOTE_HOST}:${LOCAL_PATH}/${file_name}" && \
                log_check_message "[info] Transferred k8s backup for ${db_name}" || \
                log_check_message "[error] Transfer failed for k8s backup ${db_name}"
                rm -f "$tmp_backup"
            else
                mkdir -p "${LOCAL_PATH}/${db_name}"
                mv "$tmp_backup" "${LOCAL_PATH}/${db_name}/${file_name}" && \
                log_check_message "[info] K8s backup saved locally for ${db_name}" || \
                log_check_message "[error] Failed to save k8s backup for ${db_name}"
            fi
            ;;
    esac
}