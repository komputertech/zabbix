
# Monitorowanie bazy Microsoft SQL Server

Monitorowanie baz Microsoft można uzyskać poprzez połączenie ODBC lub wykorzystać wtyczkę dla Agent 2. Obydwie metody nie są trudne do wdrożenia. W przypadku użycia ODBC, konfiguracja jest trudniejsza do zarządzania, trzeba również pamiętać, że wersja sterownika musi obsługiwać nasz serwer SQL (oraz aktualny poziom CU).

## Serwer SQL

Wykonać polecenia z szablonu, czyli dodanie użytkownika do instancji wraz z rolami i dostępami:

```sql
CREATE LOGIN zbx_monitor WITH PASSWORD = '<password>';
USE master;
GRANT VIEW SERVER STATE TO zbx_monitor;
GRANT VIEW ANY DEFINITION TO zbx_monitor;
USE msdb;
CREATE USER zbx_monitor FOR LOGIN zbx_monitor;
GRANT SELECT ON OBJECT::msdb.dbo.sysjobs TO zbx_monitor;
GRANT SELECT ON OBJECT::msdb.dbo.sysjobservers TO zbx_monitor;
GRANT SELECT ON OBJECT::msdb.dbo.sysjobactivity TO zbx_monitor;
GRANT EXECUTE ON OBJECT::msdb.dbo.agent_datetime TO zbx_monitor;
```

## Serwer Zabbix - Monitorowanie poprzez ODBC

1. Instalacja sterownika ODBC ze strony Microsoft (wraz z MSSQL Tools, oraz UnixODBC Dev) w wersji 18:

    ```bash
    curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
    curl https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
    curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
    sudo apt update
    sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18
    sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
    source ~/.bashrc
    sudo apt-get install -y unixodbc-dev

    ```

2. Sprawdzenie poprawności konfiguracji: `odbcinst -j`
3. Sprawdzenie sterownika MS ODBC Driver 18 for SQL Server: `odbcinst -q -d`
4. Utworzenie lub edycja pliku: `/etc/odbc.ini`

    ```text
    [SQLname]  
    Driver = ODBC Driver 18 for SQL Server
    Server=<IP ADDRESS>
    Encrypt=NO
    TrustServerCertificate=YES
    ```

5. Sprawdzenie poprawności DSN: `odbcinst -q -s`
6. Sprawdzenie połączenia: `isql -v <DSN> <login> <password>`
7. Zabbix Web GUI, dodać nowy Host i dodać makra według instrukcji:
    * {$MSSQL.DSN} - to nazwa z pliku odbc.ini
    * {$MSSQL.USER} - zbx_monitor
    * {$MSSQL.PASSWORD} - hasło
    * {$MSSQL.INSTANCE} - MSSQL$instance (server\instance), jeśli domyślna pominąć
    * {$MSSQL.PORT} - jeśli port inny niż 1433
    * {$MSSQL.HOST} - adres IP serwera
8. Dodać szablon MSSQL by ODBC i sprawdzić Ostatnie Dane.

## Serwer SQL - Monitorowanie poprzez Agent 2 MSSQL Plugin

1. Pobieramy wtyczkę:
    * dla wszystkich systemów: `https://cdn.zabbix.com/zabbix/binaries/stable/7.0/`
    * dla Linux z repozytorium Zabbix `sudo apt install zabbix-agent2-plugin-mssql`
2. W przypadku Linux, nie potrzeba dodatkowej konfiguracji, dla Windows, należy dodać plik mssql.conf i wpis konfiguracyjny.
    * Dodanie wpisu: `Include=C:\Program Files\Zabbix Agent 2\mssql.conf` W pliku konfiguracji agenta: `C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf`
    * Dodanie wpisu: `Plugins.MSSQL.System.Path=C:\Program Files\Zabbix Agent 2\zabbix-agent2-plugin-mssql.exe` W pliku konfiguracji: `C:\Program Files\Zabbix Agent 2\mssql.conf`
3. Zabbix Web GUI, dodać nowy Host i dodać makra według instrukcji:
    * {$MSSQL.URI} - sqlserver://IP_ADDRESS,PORT
    * {$MSSQL.USER} - zbx_monitor
    * {$MSSQL.PASSWORD} - hasło
    * {$MSSQL.INSTANCE} - MSSQL$instance (server\instance), jeśli domyślna pominąć
    * {$MSSQL.PORT} - jeśli port inny niż 1433
    * {$MSSQL.HOST} - adres IP serwera
4. Dodać szablon MSSQL by Zabbix agent 2 i sprawdzić Ostatnie Dane.
