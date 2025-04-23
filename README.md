[English](#english) • [Español](#español)  

## English  

This document describes how to configure and use a Bash backup script with GPG symmetric encryption (AES-256) and how to set up log rotation using **logrotate**. It covers installation prerequisites, script configuration, manual decryption steps, and logrotate integration to automatically manage log files.

## Prerequisites  
- GPG version ≥ 1.4 or ≥ 2.1 installed on the system.  
- Bash, mysqldump, gzip, AWS CLI or gsutil (depending on cloud mode) available in PATH.  
- A passphrase stored securely (e.g. environment variable or config file with proper permissions).  

### GPG symmetric mode  
GPG symmetric encryption uses a passphrase to derive an encryption key via String-to-Key (S2K) with SHA256 and iteration counts, and embeds a Modification Detection Code (MDC) for integrity checks.  

## Script Configuration  
1. Place the script (e.g. `backup-databases.sh`) in a chosen directory.  
2. Create a config file `mysql-databases.conf` alongside it with variables:  
    - DB_USER, DB_PASS  
    - DEFAULT_CLOUD_BUCKET, CLOUD_BUCKET  
    - LOCAL_PATH, REMOTE_HOST  
    - RETENTION_DAYS, ENCRYPTION_KEY  
    - MODE (gcp, local, s3, k8s), K8S_POD, K8S_NAMESPACE  
3. Ensure `ENCRYPTION_KEY` is set to your GPG passphrase.  

## Script Overview  
- **Logging**: Writes to `/var/log/backups-databases.log` with timestamps.  
- **Database listing**: Excludes `information_schema`, `performance_schema`, `sys`.  
- **Backup pipeline**:  
    1. `mysqldump --single-transaction`  
    2. `gzip`  
    3. `gpg --symmetric --cipher-algo AES256 --compress-algo none --passphrase "$ENCRYPTION_KEY" --pinentry-mode loopback`  
- **Modes**:  
    - `local` and `k8s`: save to local path or remote via `scp`.  
    - `s3`: upload to AWS S3.  
    - `gcp`: upload to Google Cloud Storage.  

## Manual Decryption  
To decrypt a backup file (e.g. `db-20250422-1200.sql.gz.gpg`):  
    gpg --batch --yes   
        --decrypt   
        --passphrase "YOUR_PASSPHRASE"   
        --pinentry-mode loopback   
        --output db-20250422-1200.sql.gz   
        db-20250422-1200.sql.gz.gpg  
    gzip -d db-20250422-1200.sql.gz  

## Logrotate Integration  
Create `/etc/logrotate.d/backups-databases` with:  
    /var/log/backups-databases.log {  
        daily                  # rotate each day  
        rotate 7               # keep 7 days  
        compress               # gzip old logs  
        delaycompress          # skip compression on the most recent  
        copytruncate           # truncate original after copy  
        missingok              # no error if log is missing  
        notifempty             # do not rotate empty files  
        create 640 root adm    # permissions and ownership  
    }  

Test configuration:  
    logrotate --debug /etc/logrotate.d/backups-databases  

---

## Español  

Este documento describe cómo configurar y usar un script de copias de seguridad en Bash con cifrado simétrico GPG (AES-256) y cómo configurar la rotación de logs con **logrotate**. Incluye requisitos, configuración del script, desencriptado manual e integración de logrotate.

## Requisitos  
- GPG versión ≥ 1.4 o ≥ 2.1 instalado.  
- Bash, mysqldump, gzip, AWS CLI o gsutil en el PATH.  
- Passphrase seguro (variable de entorno o archivo de configuración con permisos restrictivos).  

### Modo simétrico de GPG  
GPG simétrico deriva la clave desde la contraseña con S2K SHA256 e iteraciones, e incluye un Código de Detección de Modificación (MDC) para integridad.  

## Configuración del Script  
1. Copia el script (`backup-databases.sh`) en el directorio deseado.  
2. Crea `mysql-databases.conf` al lado con variables:  
    - DB_USER, DB_PASS  
    - DEFAULT_CLOUD_BUCKET, CLOUD_BUCKET  
    - LOCAL_PATH, REMOTE_HOST  
    - RETENTION_DAYS, ENCRYPTION_KEY  
    - MODE (gcp, local, s3, k8s), K8S_POD, K8S_NAMESPACE  
3. Asegura que `ENCRYPTION_KEY` contenga tu passphrase de GPG.  

## Descripción del Script  
- **Logging**: `/var/log/backups-databases.log` con timestamps.  
- **Listar DBs**: excluye `information_schema`, `performance_schema`, `sys`.  
- **Pipeline de backup**:  
    1. `mysqldump --single-transaction`  
    2. `gzip`  
    3. `gpg --symmetric --cipher-algo AES256 --compress-algo none --passphrase "$ENCRYPTION_KEY" --pinentry-mode loopback`  
- **Modos**:  
    - `local` y `k8s`: guarda localmente o envía por `scp`.  
    - `s3`: sube a AWS S3.  
    - `gcp`: sube a Google Cloud Storage.  

## Desencriptado Manual  
Para desencriptar un archivo (por ej. `db-20250422-1200.sql.gz.gpg`):  
    gpg --batch --yes   
        --decrypt   
        --passphrase "TU_PASSPHRASE"   
        --pinentry-mode loopback   
        --output db-20250422-1200.sql.gz   
        db-20250422-1200.sql.gz.gpg  
    gzip -d db-20250422-1200.sql.gz  

## Integración con Logrotate  
Crea `/etc/logrotate.d/backups-databases`:  
    /var/log/backups-databases.log {  
        daily                  # rota diario  
        rotate 7               # conserva 7 días  
        compress               # comprime logs antiguos  
        delaycompress          # comprime desde la segunda rotación  
        copytruncate           # trunca original tras copiar  
        missingok              # no error si falta el log  
        notifempty             # no rota logs vacíos  
        create 640 root adm    # permisos y dueño  
    }  

Prueba la configuración:  
    logrotate --debug /etc/logrotate.d/backups-databases  
