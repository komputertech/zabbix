
# Dodanie agenta do Zabbix

## Windows

1. Pobrać Agent2
2. Wykonać instalację, dane wymagane:
    * Hostname - nazwa komputera
    * Server IP - adres Zabbix
    * Listen port - zostawić 10050
    * Active check - zostawić puste, jeśli nie używamy trybu aktywnego
    * zaznaczyć Enable PSK i Add agent to PATH
    * Pre-shared key identity - unikalne
    * Pre-shared key value - wygenerowany klucz psk
3. Dodać klienta do serwera Zabbix

## Linux

1. Dodać repozytorium i zainstalować Agent2
2. Wygenerować klucz PSK

    ```bash
    openssl rand -hex 32 > key.psk
    sudo mv key.psk /etc/zabbix/
    sudo chown root:zabbix /etc/zabbix/key.psk
    sudo chmod 640 /etc/zabbix/key.psk
    ```

3. Zmodyfikować plik agenta Zabbix `/etc/zabbix/zabbix_agent2.conf`

    ```text
    Hostname - nazwa komputera
    Server - adres Zabbix
    TLSConnect=psk
    TLSAccept=psk
    TLSPPSKIdentity=unikalne
    TLSPSKFile=/etc/zabbix/key.psk
    ```

4. Zapora sieciowa
    * Ubuntu:

    ```bash
    sudo ufw allow from 192.168.0.12 to any port 10050 proto tcp
    ```

    * Oracle Linux:

    ```bash
    sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.12" port protocol="tcp" port="10050" accept'
    sudo firewall-cmd --reload
    ```

5. Uruchomienie agenta

    ```bash
    sudo systemctl restart zabbix-agent2.service
    sudo systemctl enable zabbix-agent2.service
    ```

6. Dodać klienta do serwera Zabbix
