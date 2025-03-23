
# Monitorowanie WEB

## Szablon Website by Browser

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
        * Website by Browser
        * Interfaces: Agent 127.0.0.1
    * Macros:
        * {$WEBSITE.DOMAIN} komputertech.pl

## Szablon Website certificate by Zabbix agent 2

1. Utworzenie nowego hosta - Zabbix GUI - Data collection -> Hosts -> Create host
    * Host name: komputertech.pl
    * Host groups: WWW
    * Templates:
        * Website certificate by Zabbix agent 2
        * Interfaces: Agent 127.0.0.1
    * Macros:
        * {$CERT.WEBSITE.HOSTNAME} komputertech.pl
        * {$WEBSITE.DOMAIN} komputertech.pl

## Kolekcja Data collection WEB

1. Dodanie zakładki Web - Zabbix GUI - Data collection -> Hosts i wybieramy "Web" obok nazwy hosta komputertech.pl
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

## Monitorowanie zawartości strony

1. Potrzebujemy podglądnąć stronę, tak jak ją widzi Zabbix, używamy curl, w naszym przypadku będzie to serwer z Apache2 z domyślną stroną.
2. Po ustaleniu, który fragment chcemy odczytywać, budujemy regex, w naszym przypadku będzie to: `<div class="content_section_text">\s*<p>\s+([^.]+.)`
3. Tworzymy szablon Monitor website content
    * Klikamy Template -> New template
        * Zakładka Template
            * Name: Monitor website content
        * Zakładka Macro piersze:
            * Macro: {$WEB.MONITOR.CONTENT.URL}
            * Value: none
            * Description: URL to monitored site
        * Zakładka Macro druie
            * Macro: {$WEB.MONITOR.CONTENT.REGEX}
            * Value: none
            * Description: Search for selected text
    * Klikamy Create item
        * zakładka Item
            * Name: Website content
            * Type: Zabbix agent
            * Key: web.page.get[{$WEB.MONITOR.CONTENT.URL}]
            * Type of information: Text
            * Update interval: 3m
            * Timeout: Global
            * History: Story up to 31d
        * zakładka Preprocessing
            * Regular expression
                * pattern: {$WEB.MONITOR.CONTENT.REGEX}
                * output: {$WEB.MONITOR.CONTENT.REGEX.GROUP}
            * Custom on fail: Set value to: error
    * Stworzenie wyzwalacza, klikamy Create trigger
        * Name: Webpage works!
        * Severity: Informatinal
        * Expression: last(/Monitor website content/web.page.get[{$WEB.MONITOR.CONTENT.URL}])<>"error"
