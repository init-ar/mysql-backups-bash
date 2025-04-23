*[English](#english) | [Español](#español)*

# English

# Database Backup Script Documentation

## Overview

This script is designed for automated MySQL database backups with support for multiple environments and deployment scenarios. It offers flexible options for backing up to various destinations including local storage, remote servers, Google Cloud Storage, AWS S3, and Kubernetes environments.

## Features

- Multiple backup destination options:
    - Local filesystem storage  
    - Remote server via SSH  
    - Google Cloud Storage buckets  
    - AWS S3 buckets  
    - Kubernetes pods via port-forwarding  
- Backup encryption using AES-256 via GPG  
- Customizable retention policy  
- Comprehensive logging  
- Excluding system databases from backups  
- Log rotation using **logrotate**

## Prerequisites

- MySQL client tools for database connection  
- Appropriate credentials for database access  
- Required cloud CLI tools if using cloud storage:  
    - `gsutil` for Google Cloud Storage  
    - AWS CLI for S3 backups  
- `kubectl` if using Kubernetes mode  
- GPG (version ≥ 1.4 or ≥ 2.1) installed  

### Creating a MySQL Backup User

Use the following SQL commands to create a backup user with minimal privileges required to run `mysqldump`:

    -- Create the backup user
    CREATE USER 'user_backups'@'localhost' IDENTIFIED BY 'PASSWD';

    -- Grant backup privileges (read-only access to all databases)
    GRANT SELECT, SHOW VIEW, PROCESS, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'user_backups'@'localhost';

    -- Apply privileges
    FLUSH PRIVILEGES;

Make sure to replace `'PASSWD'` with a strong password and update the corresponding value in the script.

## Usage

    ./backup-script.sh [options]

### Command Line Options

| Option | Description |
|--------|-------------|
| `-m`   | Mode of backup: `gcp`, `local`, `s3`, or `k8s` |
| `-l`   | Local backup path or remote destination path |
| `-b`   | Cloud bucket path (for GCP or S3 modes) |
| `-k`   | Encryption key (GPG passphrase) |
| `-T`   | Retention period in days |
| `-h`   | Remote host address (format: user@host) |
| `-P`   | Kubernetes pod name (required for k8s mode) |
| `-N`   | Kubernetes namespace (default: "default") |

### Backup Modes

1. **Local Mode** (`-m local`)  
   - Saves backups to a local directory  
   - Can transfer to a remote host if `-h` is specified  

2. **Google Cloud Storage** (`-m gcp`)  
   - Uploads backups directly to a GCS bucket  
   - Requires `gsutil` to be configured  

3. **AWS S3** (`-m s3`)  
   - Uploads backups directly to an S3 bucket  
   - Requires AWS CLI to be configured  

4. **Kubernetes** (`-m k8s`)  
   - Connects to a database in a Kubernetes pod using port-forwarding  
   - Requires `kubectl` access to the specified cluster  

### Examples

    # Local backup with 7-day retention
    ./backup-script.sh -m local -l /backups/mysql -T 7

    # Encrypted backup to Google Cloud Storage
    ./backup-script.sh -m gcp -b gs://my-bucket/path -k mysecret

    # Backup from Kubernetes pod
    ./backup-script.sh -m k8s -P my-mysql-pod -N my-namespace -l /backups/mysql

    # Local backup with transfer to remote host
    ./backup-script.sh -m local -l /backups/mysql -h user@remotehost

## Configuration

The script uses several default configuration values that can be modified at the top of the script:

    DB_USER="user_backups"           # Database username
    DB_PASS="PASSWD"                 # Database password
    DEFAULT_CLOUD_BUCKET="gs://bucket-backups-servers/databases"  # Default GCS bucket
    LOG_FILE="/var/log/backups-databases.log"                     # Log file location
    ENCRYPTION_KEY=""               # GPG passphrase

## Backup Process

For each database:

1. The script connects to MySQL and retrieves a list of databases (excluding system databases)  
2. For each database, it runs `mysqldump` with the `--single-transaction` flag  
3. Output is compressed with `gzip`  
4. If `ENCRYPTION_KEY` is set, AES-256 encryption is applied via GPG:  
       
        gzip output | gpg --batch --yes \
            --symmetric \
            --cipher-algo AES256 \
            --compress-algo none \
            --passphrase "$ENCRYPTION_KEY" \
            --pinentry-mode loopback \
            --output db-name-YYYYMMDD-HHMM.sql.gz.gpg  

5. The backup is transferred to the specified destination  
6. For `local` and `k8s` modes, old backups are deleted based on the retention policy  

## Manual Decryption

To decrypt a backup file (e.g. `db-20250422-1200.sql.gz.gpg`):

    gpg --batch --yes \
        --decrypt \
        --passphrase "YOUR_PASSPHRASE" \
        --pinentry-mode loopback \
        --output db-20250422-1200.sql.gz \
        db-20250422-1200.sql.gz.gpg
    gzip -d db-20250422-1200.sql.gz

## Logging

All operations are logged to the file specified in `LOG_FILE` with timestamps and status information. Errors are also recorded in this log.

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

# Español

# Documentación del Script de Respaldo de Bases de Datos

## Descripción General

Este script está diseñado para automatizar los respaldos de bases de datos MySQL con soporte para múltiples entornos y escenarios de implementación. Ofrece opciones flexibles para realizar copias de seguridad en varios destinos, incluyendo almacenamiento local, servidores remotos, Google Cloud Storage, AWS S3 y entornos Kubernetes.

## Características

- Múltiples opciones de destino para los respaldos:  
    - Almacenamiento en sistema de archivos local  
    - Servidor remoto mediante SSH  
    - Buckets de Google Cloud Storage  
    - Buckets de AWS S3  
    - Pods de Kubernetes mediante port-forwarding  
- Cifrado de respaldos usando AES-256 vía GPG  
- Política de retención personalizable  
- Registro completo de operaciones  
- Exclusión de bases de datos del sistema  
- Rotación de logs con **logrotate**

## Requisitos Previos

- Herramientas cliente de MySQL para la conexión a la base de datos  
- Credenciales apropiadas para el acceso a la base de datos  
- Herramientas CLI necesarias si se usa almacenamiento en la nube:  
    - `gsutil` para Google Cloud Storage  
    - AWS CLI para respaldos en S3  
- `kubectl` si se usa el modo Kubernetes  
- GPG (versión ≥ 1.4 o ≥ 2.1) instalado  

### Creación del Usuario de Backup en MySQL

Utiliza los siguientes comandos SQL para crear un usuario de backup con los privilegios mínimos necesarios para ejecutar `mysqldump`:

    -- Crear el usuario de backup
    CREATE USER 'user_backups'@'localhost' IDENTIFIED BY 'PASSWD';

    -- Otorgar privilegios de backup (acceso de solo lectura a todas las bases de datos)
    GRANT SELECT, SHOW VIEW, PROCESS, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'user_backups'@'localhost';

    -- Aplicar privilegios
    FLUSH PRIVILEGES;

Asegúrate de reemplazar `'PASSWD'` con una contraseña segura y actualizar el valor correspondiente en el script.

## Uso

    ./backup-script.sh [opciones]

### Opciones de Línea de Comandos

| Opción | Descripción |
|--------|-------------|
| `-m`   | Modo de respaldo: `gcp`, `local`, `s3`, o `k8s` |
| `-l`   | Ruta de respaldo local o ruta de destino remoto |
| `-b`   | Ruta del bucket en la nube (para modos GCP o S3) |
| `-k`   | Passphrase para GPG |
| `-T`   | Período de retención en días |
| `-h`   | Dirección del host remoto (formato: usuario@host) |
| `-P`   | Nombre del pod de Kubernetes (requerido para modo k8s) |
| `-N`   | Namespace de Kubernetes (predeterminado: "default") |

### Modos de Respaldo

1. **Modo Local** (`-m local`)  
   - Guarda respaldos en un directorio local  
   - Puede transferir a un host remoto si se especifica `-h`  

2. **Google Cloud Storage** (`-m gcp`)  
   - Sube respaldos directamente a un bucket de GCS  
   - Requiere que `gsutil` esté configurado  

3. **AWS S3** (`-m s3`)  
   - Sube respaldos directamente a un bucket de S3  
   - Requiere que AWS CLI esté configurado  

4. **Kubernetes** (`-m k8s`)  
   - Se conecta a una base de datos en un pod de Kubernetes mediante port-forwarding  
   - Requiere acceso de `kubectl` al clúster especificado  

### Ejemplos

    # Respaldo local con retención de 7 días
    ./backup-script.sh -m local -l /backups/mysql -T 7

    # Respaldo cifrado a Google Cloud Storage
    ./backup-script.sh -m gcp -b gs://my-bucket/path -k misecret

    # Respaldo desde un pod de Kubernetes
    ./backup-script.sh -m k8s -P my-mysql-pod -N my-namespace -l /backups/mysql

    # Respaldo local con transferencia a host remoto
    ./backup-script.sh -m local -l /backups/mysql -h usuario@hostremoto

## Configuración

El script utiliza varios valores de configuración predeterminados que pueden modificarse en la parte superior del script:

    DB_USER="user_backups"           # Usuario de la base de datos
    DB_PASS="PASSWD"                 # Contraseña de la base de datos
    DEFAULT_CLOUD_BUCKET="gs://bucket-backups-servers/databases"  # Bucket GCS predeterminado
    LOG_FILE="/var/log/backups-databases.log"                     # Ubicación del archivo de registro
    ENCRYPTION_KEY=""               # Passphrase para GPG

## Proceso de Respaldo

Para cada base de datos:

1. El script se conecta a MySQL y recupera una lista de bases de datos (excluyendo las del sistema)  
2. Para cada base de datos, ejecuta `mysqldump` con la bandera `--single-transaction`  
3. La salida se comprime con `gzip`  
4. Si `ENCRYPTION_KEY` está definido, se aplica cifrado AES-256 vía GPG:

        gzip output | gpg --batch --yes \
            --symmetric \
            --cipher-algo AES256 \
            --compress-algo none \
            --passphrase "$ENCRYPTION_KEY" \
            --pinentry-mode loopback \
            --output nombre-db-YYYYMMDD-HHMM.sql.gz.gpg

5. El respaldo se transfiere al destino especificado  
6. Para modos `local` y `k8s`, los respaldos antiguos se eliminan según la política de retención  

## Desencriptado Manual

Para desencriptar un archivo (por ej. `db-20250422-1200.sql.gz.gpg`):

    gpg --batch --yes \
        --decrypt \
        --passphrase "TU_PASSPHRASE" \
        --pinentry-mode loopback \
        --output db-20250422-1200.sql.gz \
        db-20250422-1200.sql.gz.gpg
    gzip -d db-20250422-1200.sql.gz

## Registro de Operaciones

Todas las operaciones se registran en el archivo especificado en `LOG_FILE` con marcas de tiempo e información de estado. Los errores también se registran en este archivo.

## Integración con Logrotate

Crea `/etc/logrotate.d/backups-databases`:

    /var/log/backups-databases.log {
        daily                  # rota cada día
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
