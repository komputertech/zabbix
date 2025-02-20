
# Monitorowanie WEB

1. Instalacja Selenium w Podman:

    ```bash
    sudo apt install podman
    echo 'unqualified-search-registries = ["docker.io"]' | sudo tee -a /etc/containers/registries.conf
    sudo useradd -m container
    sudo passwd container
    su -s /bin/bash - container
    podman run --name browser -p 4444:4444 -p 7900:7900 --shm-size="2g" -d selenium/standalone-chrome:latest
    podman generate systemd --new --name browser -f
    mkdir /home/container/.config/systemd/user/
    mv -v container-browser.service ~/.config/systemd/user/
    exit
    su - container
    systemctl --user daemon-reload
    systemctl --user enable container-browser.service
    systemctl --user enable podman-restart.service
    exit
    sudo loginctl enable-linger container
    sudo passwd -l container
    ```

2. Edycja pliku: `/etc/zabbix/zabbix_server.conf`
    * WebDriverURL=127.0.0.1:4444
    * StartBrowserPollers=1
3. Restart usługi:

    ```bash
    sudo service zabbix-server restart
    ```

4. Utworzenie nowego hosta - Zabbix GUI - Data collection -> Hosts -> Create host
    * Host name: komputertech.pl
    * Host groups: WWW
    * Templates:
        * Website certificate by Zabbix agent 2
        * Website by Browser
        * Interfaces: Agent 127.0.0.1
    * Macros:
        * {$CERT.WEBSITE.HOSTNAME} komputertech.pl
        * {$WEBSITE.DOMAIN} komputertech.pl
5. Dodanie zakładki Web - Zabbix GUI - Data collection -> Hosts i wybieramy "Web" obok nazwy hosta komputertech.pl
    * klikamy "Create web scenario"
    * zakładka Scenario:
        * Name: WS komputertech.pl
    * zakładka Steps - Add:
        * Name: Main
        * URL: komputertech.pl
        * Follow redirects: enable
        * Required status codes: 200
    * zakładka Authentication:
        * SSL verify host: enable
    * klikamy Update
