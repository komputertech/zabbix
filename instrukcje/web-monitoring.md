
# Monitorowanie stron WWW

## Szablon Website by Browser

Instalujemy Docker Engine, najlepiej z rekomendowanego repozytorium: [link do instrukcji](https://docs.docker.com/engine/install/ubuntu/) oraz wgrywamy pakiet docker-compose. Dalej najlepiej w /opt utworzyć katalog dla naszego Selenium oraz utworzyć plik yaml:

```bash
sudo apt install docker-compose
sudo mkdir /opt/selenium
sudo nano /opt/selenium/compose.yml
```

```text
version: '3.8'

services:
browser:
    image: docker.io/selenium/standalone-chrome:latest
    container_name: browser
    ports:
    - "4444:4444"   # Selenium WebDriver
    - "7900:7900"   # VNC Viewer (opcjonalnie)
    shm_size: "2g"
    restart: always
```

Uruchamiamy kontener za pomocą polecenia:

```bash
sudo docker-compose up -d
```

Przechodzimy do edycji pliku konfiguracyjnego Zabbix `/etc/zabbix/zabbix_server.conf` i dodajemy lub edytujemy na końcu wpis i restartujemy usługę zabbix-server.

```text
WebDriverURL=127.0.0.1:4444
StartBrowserPollers=1
```

```bash
udo service zabbix-server restart
```

W WebGUI tworzymy nowego hosta: Data collection -> Hosts -> Create host

- Host name: komputertech.pl
- Host groups: WWW
- Templates:
  - Website by Browser
  - Interfaces: Agent 127.0.0.1
- Macros:
  - {$WEBSITE.DOMAIN} komputertech.pl

## Szablon Website certificate by Zabbix agent 2

Tworzymy nowy host lub edytujemy poprzedni: Data collection -> Hosts -> Create host

- Host name: komputertech.pl
- Host groups: WWW
- Templates:
  - Website certificate by Zabbix agent 2
  - Interfaces: Agent 127.0.0.1
- Macros:
  - {$CERT.WEBSITE.HOSTNAME} komputertech.pl
  - {$WEBSITE.DOMAIN} komputertech.pl

## Kolekcja Data collection WEB

Dodajemy zakładkę Web: Data collection -> Hosts i wybieramy "Web" obok nazwy hosta komputertech.pl

- klikamy "Create web scenario"
- zakładka Scenario:
  - Name: WS komputertech.pl
  - zakładka Steps - Add:
    - Name: Main
    - URL: komputertech.pl
    - Follow redirects: enable
    - Required status codes: 200
  - zakładka Authentication:
    - SSL verify host: enable
  - klikamy Update

## Monitorowanie zawartości strony

Jeśli chcemy monitorować konkretną część strony, np. problem na stronie głównej naszej aplikacji i status tego błędu, możemy wykorzystać wbudowany obiekt web.page.get. Działa on jak curl, więc niejako wyświetla zawartość strony. Najprościej zobaczyć to używając curl, z poziomu Zabbix. W naszym przypadku będzie to serwer z Apache2 z domyślną stroną, zabezpieczoną przed odczytem. Chcemy monitorować i wysłać alert, jeśli ten stan by się zmienił i strona stała by się dostępna. Tak wygląda strona po użyciu curl:

```text
<html><head>
<title>401 unauthorize</title>
</head><body>
<p>This server could not verify that you
are authorized to access the document
requested.</p>
</body></html>
```

Po ustaleniu, który fragment chcemy odczytywać, budujemy regex, który  w naszym przypadku będzie: `<title>\K(?:\w|\s)+`. Działanie możemy sprawdzić, wykonując polecenie `curl -s | grep -Po '<title>\K(?:\w|\s)+'`  Tworzymy szablon:

- Klikamy Template -> New template
  - Zakładka Template
    - Name: Monitor website content
  - Zakładka Macro piersze:
    - Macro: `{$WEB.MONITOR.CONTENT.URL}`
    - Value: none
    - Description: URL to monitored site
  - Zakładka Macro drugie
    - Macro: `{$WEB.MONITOR.CONTENT.REGEX}`
    - Value: none
    - Description: Search for selected text
  - Zakładka Macro drugie
    - Macro: `{$WEB.MONITOR.CONTENT.WANTED}`
    - Value: none
    - Description: What you expected to see
  - Klikamy Create item
    - zakładka Item
      - Name: Website content
      - Type: Zabbix agent
      - Key: `web.page.get[{$WEB.MONITOR.CONTENT.URL}]`
      - Type of information: Text
      - Update interval: 3m
      - Timeout: Global
      - History: Store up to 31d
    - zakładka Preprocessing
      - Regular expression
      - pattern: `{$WEB.MONITOR.CONTENT.REGEX}`
      - output: \0
    - Custom on fail: Set value to: error
  - Stworzenie wyzwalacza, klikamy Create trigger
    - Name: Webpage works!
    - Severity: Informatinal
    - Expression: `last(/Monitor website content/web.page.get[{$WEB.MONITOR.CONTENT.URL}])<>"{$WEB.MONITOR.CONTENT.WANTED}"`

Zasada działania szablonu, mamy 3 makra - adres strony, regex i oczekiwana odpowiedź. Szablon musi być nałożony na serwer Zabbix, czyli korzystamy z adresu agenta 127.0.0.1. Zgodnie z szablonem zostanie sprawdzona wskazana strona, wykonany regex na otrzymanych danych, a te dane sprawdzone z tym czego oczekujemy. Jeśli otrzymamy inną odpowiedź, zostanie wyświetlona informacja o błędzie. Dodatkowo zabezpieczamy się, gdyby przetworzenie zwróciło jakiś błąd to również wyświetli błąd, że coś jest nie tak.
