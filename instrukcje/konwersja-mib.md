# Konwersja MIB do szalonu Zabbix

Konwersja w tym przykładzie MIB dla urządzenia UPS. Korzystam z narzędzia mib2zabbix napisanego w Perl.

## Instalacja pakietów SNMP

```bash
sudo apt-get update
sudo apt install snmp snmp-mibs-downloader
```

## Sprawdzenie root OID

Sprawdzenie dostępnych OID w urządzeniu, oraz komunikacji, najlepiej wywołać na serwerze Zabbix, któy będzie monitorował. Minimalne potrzebne informacje to wersja protokołu, hasło community, adres i root OID.

Sprawdzamy w pliku MIB sekcje **MODULE-IDENTITY**, i szukamy na jej końcu takiego wpisu `::= { }` określającego root OID. Musimy rozszyfrować to co w środku dla konwertera. Informacje można znaleźć np. w `cat /usr/share/snmp/mibs/ietf/SNMPv2-SMI`, jeśli poszukujemy nietypowych ścieżek. Sprawdzamy w tabeli poniżej:

| Nazwa        | Definicja      | OID            |
|--------------|----------------|----------------|
| internet     | { dod 1 }      | 1.3.6.1        |
| mgmt         | { internet 2 } | 1.3.6.1.2      |
| mib-2        | { mgmt 1 }     | 1.3.6.1.2.1    |
| transmission | { mib-2 10 }   | 1.3.6.1.2.1.10 |
| private      | { internet 4 } | 1.3.6.1.4      |
| enterprises  | { private 1 }  | 1.3.6.1.4.1    |

Tak więc np. dla `::= { mib-2 33 }` mamy `1.3.6.1.2.1`, a dla `::= { enterprises 50536 }` otrzymujemy `1.3.6.1.4.1`.

```bash
snmpwalk -h
snmpwalk -v2c -c public 192.168.1.100 .1.3.6.1.2.1
```

## Konfiguracja MIB

Pobierz brakujące MIB:

```bash
sudo download-mibs
```

Sprawdzamy w MIB początek, sekcje **IMPORTS** i patrzymy na moduły wpisane za **FROM**, zapisujemy wszystkie, przydadzą się do konfiguracji (przykład):

```text
   IMPORTS
       MODULE-IDENTITY, OBJECT-TYPE, NOTIFICATION-TYPE,
       OBJECT-IDENTITY, Counter32, Gauge32, Integer32
           FROM SNMPv2-SMI
       DisplayString, TimeStamp, TimeInterval, TestAndIncr,
         AutonomousType
           FROM SNMPv2-TC
       MODULE-COMPLIANCE, OBJECT-GROUP
           FROM SNMPv2-CONF;
```

Otwórz plik `/etc/snmp/snmp.conf` i ustaw, zgodnie z tym co było w pliku, jeśli załadujemy więcej, lub użyjemy +ALL może okazać się, że będziemy mieć błędy lub nadmiarowe dane (przykład):

```text
mibs +SNMPv2-SMI:SNMPv2-TC:SNMPv2-TC
mibdirs /usr/share/snmp/mibs:/usr/share/snmp/mibs/iana:/usr/share/snmp/mibs/ietf
```

Sprawdzamy poprawność z naszym MIB:

```bash
sudo snmptranslate -Tz -m +UPS-MIB.mib
```

## Instalacja mib2zabbix

Instalujemy zależności oraz pobieramy narzędzie mib2zabbix i sprawdzamy czy wszystko działa, wywołując pomoc i sprawdzając dostępne opcje:

```bash
sudo apt install libtimedate-perl libsnmp-perl libxml-simple-perl
git clone https://github.com/zabbix-tools/mib2zabbix.git
cd mib2zabbix
chmod a+x mib2zabbix.pl
perl mib2zabbix.pl -h
```

Przenosimy plik MIB do katalogu mib2zabbix i konwertujemy na szablon:

```bash
snmptranslate -Tz -m +UPS-MIB.mib | perl mib2zabbix.pl -o .1.3.6.1.2.1 -f template-ups.xml -N "UPS by SNMP" -G "CUSTOM" -e
```

## Dodanie szablonu w Zabbix

Przechodzimy do Data Collection -> Templates, w rogu u góry po prawej stronie Import, wskazujemy nasz plik XML, klikamy Import i zatwierdzamy. Gotowe.
