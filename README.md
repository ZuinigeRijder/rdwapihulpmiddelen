- [rdwapihulpmiddelen perl versie](#rdwapihulpmiddelen-perl-versie)
  - [rdw.bat](#rdwbat)
  - [rdwfinder.bat](#rdwfinderbat)
  - [missing.bat](#missingbat)


# rdwapihulpmiddelen perl versie
Perl RDW API hulpmiddelen voor de IONIQ 5, misschien dat het ook gebruikt kan worden ter inspiratie voor andere auto's. Maar kan natuurlijk ook gebruikt worden om nieuwe kentekens te vinden die nog niet op naam staan.
Voor de python versie, [zie hier](https://github.com/ZuinigeRijder/rdwapihulpmiddelen_python).

Er zijn 3 tools:
- rdw.bat: haalt IONIQ 5 kentekens op naam op
- rdwfinder.bat: vind kentekens in de opgegeven range (hoeven nog niet op naam te staan)
- missing.bat: haal de kentekens in missing.txt op en laat de nieuwe (nog niet opgehaalde) kentekens zien.

De tools worden gedraaid op Windows 10 en zijn geschreven in Perl, Perl versie die ik gebruik:
````
perl --version

This is perl, v5.8.9 built for MSWin32-x64-multi-thread
(with 9 registered patches, see perl -V for more detail)

Copyright 1987-2008, Larry Wall

Binary build 825 [288577] provided by ActiveState http://www.ActiveState.com
Built Dec 14 2008 13:01:33
````

De perl scripts gebruiken wget om data op te halen, wget versie die ik gebruik:
````
wget --version
GNU Wget 1.20.3 built on mingw32.
````

En ook curl wordt gebruikt voor https, curl versie die ik gebruik:
````
curl --version
curl 7.83.1 (Windows) libcurl/7.83.1 Schannel
Release-Date: 2022-05-13
Protocols: dict file ftp ftps http https imap imaps pop3 pop3s smtp smtps telnet tftp
Features: AsynchDNS HSTS IPv6 Kerberos Largefile NTLM SPNEGO SSL SSPI UnixSockets
````

## rdw.bat
Opgehaalde kentekens worden opgeslagen onder sub-map kentekens/ zodat alleen de delta kentekens opgehaald worden.
P.S.
- crëeer de sub-map kentekens/ handmatig
- de eerste keer zul je dus véél kentekens ophalen (meer dan 3000 voor de IONIQ 5)

3 aanroepmogelijkheden:
- zonder parameters: rdw.bat
- samenvatting: rdw.bat summary
- overzicht: rdw.bat overview

## rdwfinder.bat
Vindt kenteken in een range, handig om kentekens nog niet op naam te vinden. Bijvoorbeeld:
- rdwfinder.bat R LF 510 520 1

P.S.
Het is mogelijk dat je IP-adres geblocked gaat worden, wanneer je teveel opvragingen doet.
Hoewel er geprobeerd wordt om niet teveel opvragingen te doen.
Bij voorkeur gebruik je een VPN om dit te voorkomen.

## missing.bat
Kentekens nog niet op naam kun je handmatig in missing.txt zetten die gevonden zijn door rdwfinder. Daarna running van missing.bat zonder parameters.

P.S. rdw.bat zal ook de output van missing.outfile.txt meenemen in de resultaten.
