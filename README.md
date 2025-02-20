# MySQL Database Backup Script

*[English](#english) | [Español](#español)*

# English

## Overview
This script is a modular MySQL database backup solution that supports backups to local storage, AWS S3, or Google Cloud Platform (GCP) buckets. It features:
- Dynamic retrieval of databases (excluding system databases)
- Configurable backup modes via command-line parameters
- Optional encryption using OpenSSL (AES-256-CBC)
- Detailed logging with timestamps

## Prerequisites

- **Bash:** The script is written in Bash
- **MySQL Client:** Ensure `mysqldump` is installed and properly configured
- **AWS CLI:** Required for S3 mode (if using AWS S3)
- **gsutil:** Required for GCP mode (if using Google Cloud Storage)
- **OpenSSL:** Needed if you want to encrypt your backups
- **Permissions:** A MySQL user with privileges to perform `mysqldump`
- **Directories:**
  - **Log Directory:** Create the directory declared in the script (e.g., `/var/log/backups/`) and ensure it has proper write permissions
    ```bash
    sudo mkdir -p /var/log/backups/
    sudo chown $(whoami):$(whoami) /var/log/backups/
    ```
  - **Local Backup Directory:** If using local mode, ensure the target folder exists or the script will create it automatically

## Installation

1. **Download the Script:** Save the script (e.g., as `backup_script.sh`)
2. **Make it Executable:**
   ```bash
   chmod +x backup_script.sh
   ```

## Configuration

- Edit the script to update default values for variables such as `DB_USER`, `DB_PASS`, and the default cloud bucket
- Alternatively, override these values by passing parameters when executing the script

## Usage

Run the script with the following options:

```bash
./backup_script.sh -m <mode> -b <cloud_bucket_path> -l <local_backup_path> -k <encryption_key>
```

### Options

- `-m mode`: Backup mode. Valid options are:
  - `gcp` (default) – backup to a Google Cloud bucket
  - `local` – backup to a local directory
  - `s3` – backup to an AWS S3 bucket
- `-b cloud_bucket_path`: The cloud bucket path (used for both GCP and AWS S3)
  - Examples:
    - `gs://my-gcp-bucket/databases`
    - `s3://my-s3-bucket/databases`
- `-l local_backup_path`: The local directory for backups (used when mode is local)
- `-k encryption_key`: Optional encryption key. If provided, backups are encrypted using AES-256-CBC and the output file extension will be `.sql.gz.enc`

### Examples

GCP backup with encryption:
```bash
./backup_script.sh -m gcp -b gs://my-gcp-bucket/databases -k "mySecretKey"
```

S3 backup without encryption:
```bash
./backup_script.sh -m s3 -b s3://my-s3-bucket/databases
```

Local backup with encryption:
```bash
./backup_script.sh -m local -l /my/local/path -k "mySecretKey"
```

### Log File

The script logs all operations to `/var/log/backups/bkp-databases.log`. Make sure the log directory exists and has proper write permissions.

# Español

## Resumen
Este script es una solución modular para respaldar bases de datos MySQL que soporta copias de seguridad locales, en AWS S3 o en buckets de Google Cloud Platform (GCP). Sus características incluyen:
- Obtención dinámica de las bases de datos (excluyendo las de sistema)
- Modos de backup configurables mediante parámetros de línea de comandos
- Encriptación opcional usando OpenSSL (AES-256-CBC)
- Registro detallado con marcas de tiempo

## Requisitos

- **Bash:** El script está escrito en Bash
- **Cliente MySQL:** Asegúrate de tener instalado y configurado `mysqldump`
- **AWS CLI:** Requerido para el modo S3 (si se utiliza AWS S3)
- **gsutil:** Requerido para el modo GCP (si se utiliza Google Cloud Storage)
- **OpenSSL:** Necesario si deseas encriptar tus respaldos
- **Permisos:** Un usuario MySQL con privilegios para ejecutar `mysqldump`
- **Directorios:**
  - **Directorio de Logs:** Crea la carpeta declarada en el script (por ejemplo, `/var/log/backups/`) y asegúrate de que tenga los permisos adecuados
    ```bash
    sudo mkdir -p /var/log/backups/
    sudo chown $(whoami):$(whoami) /var/log/backups/
    ```
  - **Directorio para Backups Locales:** Si usas el modo local, asegúrate de que la carpeta de destino exista o el script la creará automáticamente

## Instalación

1. **Descarga del Script:** Guarda el script (por ejemplo, como `backup_script.sh`)
2. **Hazlo Ejecutable:**
   ```bash
   chmod +x backup_script.sh
   ```

## Configuración

- Edita el script para actualizar los valores por defecto de variables como `DB_USER`, `DB_PASS` y el bucket en la nube predeterminado
- Alternativamente, puedes sobreescribir estos valores pasando parámetros al ejecutar el script

## Uso

Ejecuta el script con las siguientes opciones:

```bash
./backup_script.sh -m <modo> -b <ruta_bucket_cloud> -l <ruta_backup_local> -k <clave_encriptacion>
```

### Opciones

- `-m modo`: Modo de backup. Las opciones válidas son:
  - `gcp` (por defecto) – backup a un bucket de Google Cloud
  - `local` – backup a un directorio local
  - `s3` – backup a un bucket en AWS S3
- `-b ruta_bucket_cloud`: La ruta del bucket en la nube (utilizada para GCP y AWS S3)
  - Ejemplos:
    - `gs://mi-bucket-gcp/databases`
    - `s3://mi-bucket-s3/databases`
- `-l ruta_backup_local`: El directorio local para los respaldos (utilizado cuando el modo es local)
- `-k clave_encriptacion`: Clave de encriptación opcional. Si se proporciona, los archivos de backup se encriptarán usando AES-256-CBC y la extensión del archivo será `.sql.gz.enc`

### Ejemplos

Backup en GCP con encriptación:
```bash
./backup_script.sh -m gcp -b gs://mi-bucket-gcp/databases -k "miClaveSecreta"
```

Backup en S3 sin encriptación:
```bash
./backup_script.sh -m s3 -b s3://mi-bucket-s3/databases
```

Backup local con encriptación:
```bash
./backup_script.sh -m local -l /mi/ruta/local -k "miClaveSecreta"
```

### Archivo de Logs

El script registra todas las operaciones en `/var/log/backups/bkp-databases.log`. Asegúrate de que el directorio de logs exista y tenga los permisos de escritura adecuados.

