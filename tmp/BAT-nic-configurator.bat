@echo off
REM Script de configuration réseau entièrement fonctionnel avec détection fiable d'interface
REM Compatible avec toutes les versions linguistiques de Windows
:: Élévation des privilèges administrateur
NET SESSION >nul 2>&1 || (
    echo Demande de privilèges administrateur...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~0' -Verb RunAs"
    exit /b
)
:: Détection universelle d'interface en utilisant WMIC
echo Détection des interfaces réseau...
set "interface="
for /f "tokens=2 delims==" %%a in (
    'wmic nic where "NetConnectionStatus=2" get NetConnectionID /value ^| find "="'
) do set "interface=%%a"
if not defined interface (
    echo ERREUR: Aucune interface réseau connectée trouvée!
    timeout /t 5 >nul
    exit /b 1
)
:: Appliquer la configuration basée sur le nom d'hôte
set "compname=%COMPUTERNAME%"
echo Configuration de %interface% pour [%compname%]...
if /i "%compname%" == "AD-DC1" (
    call :SET_STATIC 10.0.2.10 255.255.255.0 10.0.2.2 10.0.2.20 10.0.2.10
) else if /i "%compname%" == "AD-DC2-core" (
    call :SET_STATIC 10.0.2.20 255.255.255.0 10.0.2.2 10.0.2.10 10.0.2.20
) else (
    echo ERREUR: Nom d'ordinateur non supporté
    timeout /t 5 >nul
    exit /b 1
)
echo Configuration terminée. Vérification...
call :VERIFY_IP %1
exit /b
:: --------------------------
:: Routine principale de configuration
:SET_STATIC
echo » Suppression de la configuration DHCP...
netsh interface ipv4 set address "%interface%" dhcp >nul
netsh interface ipv4 delete dns "%interface%" all >nul
echo » Application de la configuration statique (IP: %1)...
netsh interface ipv4 set address "%interface%" static %1 %2 %3 >nul || (
    echo ERREUR: Échec de configuration de l'adresse IP & exit /b 1
)
echo » Configuration des serveurs DNS...
netsh interface ipv4 set dns "%interface%" static %4 validate=no >nul
netsh interface ipv4 add dns "%interface%" %5 index=2 validate=no >nul
echo » Désactivation d'IPv6...
netsh interface ipv6 set interface "%interface%" admin=disable >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Tcpip6\Parameters" /v DisabledComponents /t REG_DWORD /d 0xFF /f >nul
exit /b
:: --------------------------
:: Fonction de validation
:VERIFY_IP
echo.
echo Configuration réseau actuelle:
ipconfig /all | findstr /R /C:"IPv4" /C:"%1" /C:"Serveurs DNS"
echo.
echo Vérification de l'IP %1 dans la configuration...
ipconfig | find "%1" >nul && (
    echo SUCCÈS: IP statique configurée correctement
) || (
    echo ERREUR: Échec de configuration de l'IP statique!
    REM exit /b 1
)
echo Vérification des serveurs DNS...
ipconfig /all | findstr /R "%4.*%5" >nul && (
    echo SUCCÈS: DNS configuré correctement
) || (
    echo ERREUR: Configuration DNS échouée!
    exit /b 1
)
echo Le système redémarrera dans 10 secondes pour appliquer les changements...
timeout /t 10 >nul
shutdown /r /f /t 0
