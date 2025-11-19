# Apéndice - Backups Microsoft SQL

Se agregó la funcionalidad de hacer backups de MSSQL en servidores Windows. Esta funcionalidad utiliza las herramientas de sqlcmd, que ejecuta desde bash comandos para MSSQL. Estos comandos se ejecutan localmente en el servidor Windows, se especifica en los prerrequisitos las herramientas a instalar y la configuración necesaria.

Al momento el script solo tiene la funcionalidad de guardar localmente los backups en el sistema que corre el script.

El script copia a una carpeta temporal los dump de las bases de datos, para luego copiarlos a la carpeta de destino donde quedan empaquetados y donde se aplica la política de retención. Los dump temporales se eliminan automáticamente.

# Prerrequisitos

Instrucciones para instalar en un sistema basado en Debian:

apt install gnupg2
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
apt update
apt install mssql-tools unixodbc-dev

Agregar a PATH
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc

Se debe configurar un espacio para guardar los dumps temporales de las bases de datos (Está fuera del alcance de este documento cómo configurar una carpeta compartida, en nuestro caso se configuró una carpeta compartida por Samba).

En el servidor Windows es necesario disponder de una unidad de red mapeada, con una letra asignada. Se agrega un script de ejemplo para lograr esto "windows-persistent-mapped-drive.ps1.example", se recomienda configurarlo en el programador de tareas para ejecutar al iniciar el sistema operativo.

# Configuración

Se define en el archivo mssql.conf (Se puede cambiar ruta editando en microsoft-sql-main.sh)