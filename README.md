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
- Backup encryption using GPG with AES-256
- Customizable retention policy (default: 7 days)
- Comprehensive logging
- Automatic exclusion of system databases:
  - information_schema
  - performance_schema
  - sys

## Prerequisites

- MySQL client utilities (`mysqldump`)
- Appropriate database credentials
- **GPG (GNU Privacy Guard) for encryption**
- Cloud tools (if applicable):
  - `gsutil` for Google Cloud Storage
  - AWS CLI for S3
- `kubectl` for Kubernetes mode

### Creating a Dedicated MySQL Backup User

Recommended SQL commands to create a secure backup user:

    -- Create backup user with minimal privileges
    CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'StrongPassword123!';
    
    -- Grant required privileges
    GRANT SELECT, SHOW VIEW, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* 
    TO 'backup_user'@'localhost';
    
    FLUSH PRIVILEGES;

Replace 'StrongPassword123!' with your actual password and update the script configuration.

## Usage

    ./mysql-backup.sh [options]

### Command Line Options

| Option | Description                              | Required For |
|--------|------------------------------------------|--------------|
| `-m`   | Backup mode: gcp/local/s3/k8s            | All modes    |
| `-l`   | Local path or remote destination path    | local/k8s    |
| `-b`   | Cloud bucket path                        | gcp/s3       |
| `-k`   | GPG encryption key                       | Optional     |
| `-T`   | Retention days (default: 7)             | All modes    |
| `-h`   | Remote SSH host (user@host)              | Remote copy  |
| `-P`   | Kubernetes pod name                      | k8s mode     |
| `-N`   | Kubernetes namespace (default: default) | k8s mode     |

## Backup Process Workflow

1. Connect to MySQL server and list non-system databases
2. For each database:
    - Perform `mysqldump` with transaction consistency
    - Compress output with gzip
    - Encrypt with GPG (AES-256) if -k option provided
    - Store in configured location:
      - Local filesystem
      - Cloud storage (GCP/S3)
      - Kubernetes pod via port-forwarding
3. Apply retention policy to delete backups older than specified days

## Manual Decryption Procedure

To decrypt and restore a backup:

    1. Decrypt the GPG file:
    gpg --decrypt --batch --passphrase "YOUR_ENCRYPTION_KEY" \
        backup_file.sql.gz.gpg > decrypted_backup.sql.gz

    2. Decompress the archive:
    gzip -d decrypted_backup.sql.gz

    3. Import to MySQL:
    mysql -u [user] -p [database_name] < decrypted_backup.sql

Full pipeline example:

    gpg --decrypt --batch --passphrase "MySecureKey123" db1-20231001.sql.gz.gpg | \
    gzip -d | mysql -u root -p my_database

## Security Best Practices

1. **Credential Management**:
   - Store database passwords in configuration files (not in script)
   - Use environment variables for sensitive data
2. **Encryption Keys**:
   - Never store keys in version control
   - Rotate keys periodically
   - Use password managers for secure storage
3. **File Permissions**:
   - Set script and config files to 600
   - Restrict log file access
4. **Network Security**:
   - Use SSH keys instead of passwords for remote transfers
   - Enable SSL for cloud storage connections

---

# Español

# Documentación del Script de Respaldo MySQL

## Visión General

Este script automatiza respaldos de bases de datos MySQL con soporte para múltiples entornos. Utiliza cifrado GPG (AES-256) y ofrece opciones flexibles de almacenamiento.

## Características Clave

- Destinos múltiples:
  - Almacenamiento local
  - Transferencia remota vía SSH
  - Almacenamiento en nube (GCP/S3)
  - Entornos Kubernetes
- Cifrado GPG con AES-256
- Exclusión automática de bases del sistema
- Política de retención personalizable

## Requisitos Previos

- Herramientas cliente de MySQL
- GPG para cifrado/descifrado
- Credenciales de base de datos
- kubectl para modo Kubernetes

### Creación de Usuario de Backup

Comandos SQL recomendados:

    CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'ContraseñaFuerte!';
    GRANT SELECT, SHOW VIEW, RELOAD, LOCK TABLES, REPLICATION CLIENT 
    ON *.* TO 'backup_user'@'localhost';
    FLUSH PRIVILEGES;

## Proceso de Descifrado Manual

Para restaurar un respaldo cifrado:

    1. Descifrar archivo GPG:
    gpg --decrypt --batch --passphrase "CLAVE_SECRETA" \
        respaldo.sql.gz.gpg > respaldo_descifrado.sql.gz

    2. Descomprimir:
    gzip -d respaldo_descifrado.sql.gz

    3. Importar a MySQL:
    mysql -u usuario -p nombre_base < respaldo_descifrado.sql

Ejemplo completo:

    gpg --decrypt --batch --passphrase "MiClaveSecreta" db1-20231001.sql.gz.gpg | \
    gzip -d | mysql -u root -p mi_base_de_datos

## Consideraciones de Seguridad

1. **Almacenamiento de Credenciales**:
   - Nunca incluir contraseñas en el script
   - Usar archivos de configuración seguros
2. **Claves GPG**:
   - Rotar claves cada 3-6 meses
   - Usar contraseñas fuertes para claves
3. **Registros de Auditoría**:
   - Monitorear archivos de log regularmente
   - Implementar alertas para errores críticos
4. **Copias de Seguridad de Claves**:
   - Mantener copias offline en ubicaciones seguras
   - Usar cifrado adicional para archivos de claves

---