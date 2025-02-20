# Enhanced MySQL Database Backup Script

*[English](#english) | [Español](#español)*

# English

## Overview
This script is an enhanced modular MySQL database backup solution that supports backups to local storage, AWS S3, or Google Cloud Platform (GCP) buckets. It features:
- Dynamic retrieval of databases (excluding system databases)
- Configurable backup modes via command-line parameters
- Optional encryption using OpenSSL (AES-256-CBC)
- Detailed logging with timestamps
- Remote backup support via SSH
- Configurable retention policy
- Error handling and reporting

## Prerequisites
- **Bash:** The script is written in Bash
- **MySQL Client:** Ensure `mysqldump` is installed and properly configured
- **AWS CLI:** Required for S3 mode
- **gsutil:** Required for GCP mode
- **OpenSSL:** Needed for backup encryption
- **SSH/SCP:** Required for remote backup functionality
- **Permissions:**
  - MySQL user with `mysqldump` privileges
  - SSH key-based authentication for remote backups
  - Write permissions on backup directories

## Configuration
- **Default Values:**
  ```bash
  DB_USER="user_backups"
  DB_PASS="PASSWD"
  DEFAULT_CLOUD_BUCKET="gs://bucket-backups-servers/databases"
  LOG_FILE="/var/log/backups-databases.log"
  LOCAL_PATH="/var/backups/databases"
  RETENTION_DAYS=7
  ```

## Enhanced Usage
```bash
./backup_script.sh [-m mode] [-l backup_path] [-b cloud_bucket_path] [-k encryption_key] [-T retention_days] [-h remote_host]
```

### New Options
- `-T retention_days`: Number of days to keep backups (default: 7)
- `-h remote_host`: Remote host for backups (format: user@host)

### Examples

Remote backup with encryption:
```bash
./backup_script.sh -m local -h user@remote-server -l /backup/path -k "mySecretKey"
```

Local backup with 30-day retention:
```bash
./backup_script.sh -m local -l /my/local/path -T 30
```

# Español

## Resumen
Este script es una solución modular mejorada para respaldar bases de datos MySQL que soporta copias de seguridad locales, en AWS S3 o en buckets de Google Cloud Platform (GCP). Sus características incluyen:
- Obtención dinámica de las bases de datos (excluyendo las de sistema)
- Modos de backup configurables mediante parámetros de línea de comandos
- Encriptación opcional usando OpenSSL (AES-256-CBC)
- Registro detallado con marcas de tiempo
- Soporte para copias de seguridad remotas via SSH
- Política de retención configurable
- Manejo y reporte de errores

## Requisitos
- **Bash:** El script está escrito en Bash
- **Cliente MySQL:** Asegúrate de tener instalado y configurado `mysqldump`
- **AWS CLI:** Requerido para el modo S3
- **gsutil:** Requerido para el modo GCP
- **OpenSSL:** Necesario para encriptación de backups
- **SSH/SCP:** Requerido para funcionalidad de backup remoto
- **Permisos:**
  - Usuario MySQL con privilegios de `mysqldump`
  - Autenticación SSH basada en claves para backups remotos
  - Permisos de escritura en directorios de backup

## Configuración
- **Valores por Defecto:**
  ```bash
  DB_USER="user_backups"
  DB_PASS="PASSWD"
  DEFAULT_CLOUD_BUCKET="gs://bucket-backups-servers/databases"
  LOG_FILE="/var/log/backups-databases.log"
  LOCAL_PATH="/var/backups/databases"
  RETENTION_DAYS=7
  ```

## Uso Mejorado
```bash
./backup_script.sh [-m modo] [-l ruta_backup] [-b ruta_bucket_cloud] [-k clave_encriptacion] [-T dias_retencion] [-h host_remoto]
```

### Nuevas Opciones
- `-T dias_retencion`: Número de días para mantener los backups (por defecto: 7)
- `-h host_remoto`: Host remoto para backups (formato: usuario@host)

### Ejemplos

Backup remoto con encriptación:
```bash
./backup_script.sh -m local -h usuario@servidor-remoto -l /ruta/backup -k "miClaveSecreta"
```

Backup local con retención de 30 días:
```bash
./backup_script.sh -m local -l /mi/ruta/local -T 30
```
