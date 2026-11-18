@echo off
chcp 65001 >nul
title VPN Site-to-Site & Client-to-Site Management Utility
color 0A

:: =============================================================================
:: quick-setup.bat: Kịch bản kiểm tra và điều khiển nhanh hệ thống VPN Lab
:: Dành cho môi trường Windows (Host / Remote PC 172.16.1.100)
:: =============================================================================

:MENU
cls
echo ==============================================================================
echo       VPN SITE-TO-SITE & CLIENT-TO-SITE LAB MANAGEMENT CONTROLLER
echo ==============================================================================
echo.
echo   [1] Kiem tra ket noi mang (Ping HQ-GW, Branch-GW va HQ-Server)
echo   [2] Mo Cong Thong Tin Noi Bo HQ Web Portal (http://192.168.10.50)
echo   [3] Kiem tra bang dinh tuyen may khach (Route Print Split-Tunnel)
echo   [4] Chay Trace Route toi May chu noi bo HQ (tracert 192.168.10.50)
echo   [5] Khoi dong OpenVPN GUI tren Windows
echo   [6] SSH toi HQ Gateway (ssh student@172.16.1.10)
echo   [7] SSH toi Branch Gateway (ssh student@172.16.1.20)
echo   [8] SSH toi HQ Internal Server (ssh student@192.168.10.50)
echo   [9] Do toc do tai file 1MB bao mat tu HQ Server
echo   [0] Thoat chuong trinh
echo.
echo ==============================================================================
set /p CHOICE="Nhap lua chon cua ban [0-9]: "

if "%CHOICE%"=="1" goto PING_TEST
if "%CHOICE%"=="2" goto OPEN_PORTAL
if "%CHOICE%"=="3" goto ROUTE_CHECK
if "%CHOICE%"=="4" goto TRACERT_TEST
if "%CHOICE%"=="5" goto LAUNCH_OPENVPN
if "%CHOICE%"=="6" goto SSH_HQ_GW
if "%CHOICE%"=="7" goto SSH_BR_GW
if "%CHOICE%"=="8" goto SSH_HQ_SERVER
if "%CHOICE%"=="9" goto BENCHMARK_TEST
if "%CHOICE%"=="0" goto EXIT_SCRIPT

echo.
echo [!] Lua chon khong hop le. Vui long chon lai!
timeout /t 2 >nul
goto MENU

:PING_TEST
cls
echo ==============================================================================
echo              KIEM TRA THONG MANG (PING CONNECTIVITY TEST)
echo ==============================================================================
echo.
echo [*] 1. Ping HQ Gateway (WAN 172.16.1.10)...
ping -n 3 172.16.1.10
echo.
echo [*] 2. Ping Branch Gateway (WAN 172.16.1.20)...
ping -n 3 172.16.1.20
echo.
echo [*] 3. Ping OpenVPN Tunnel Gateway (10.8.0.1)...
ping -n 3 10.8.0.1
echo.
echo [*] 4. Ping HQ Internal Server (LAN 192.168.10.50)...
ping -n 3 192.168.10.50
echo.
echo ==============================================================================
echo [!] Neu ping 192.168.10.50 thanh cong: Ban da ket noi VPN an toan!
echo [!] Neu ping that bai: Hay bat ket noi OpenVPN GUI hoac kiem tra IP.
echo ==============================================================================
pause
goto MENU

:OPEN_PORTAL
cls
echo [*] Dang mo trinh duyet truy cap Cổng nội bộ: http://192.168.10.50 ...
start http://192.168.10.50
echo [*] Da mo trinh duyet thanh cong!
timeout /t 2 >nul
goto MENU

:ROUTE_CHECK
cls
echo ==============================================================================
echo             KIEM TRA BANG DINH TUYEN (ROUTING TABLE CHECK)
echo ==============================================================================
echo.
echo [*] Danh sach route huong toi dai mang noi bo HQ 192.168.10.0/24:
echo.
route print -4 | findstr "192.168.10. 10.8.0. Network"
echo.
echo ==============================================================================
echo [!] Ky vong: 192.168.10.0 255.255.255.0 tro qua Gateway 10.8.0.1
echo ==============================================================================
pause
goto MENU

:TRACERT_TEST
cls
echo ==============================================================================
echo         XAC NHAN DUONG DI GOI TIN QUA VPN TUNNEL (TRACEROUTE)
echo ==============================================================================
echo.
echo [*] Dang chay tracert toi 192.168.10.50 (Vui long cho vai giay)...
tracert -d 192.168.10.50
echo.
echo ==============================================================================
echo [!] Ky vong: Chang 1 la 10.8.0.1, chang 2 la 192.168.10.50 (Khong lo IP WAN)
echo ==============================================================================
pause
goto MENU

:LAUNCH_OPENVPN
cls
echo [*] Dang tim kiem va khoi chay OpenVPN GUI...
if exist "C:\Program Files\OpenVPN\bin\openvpn-gui.exe" (
    start "" "C:\Program Files\OpenVPN\bin\openvpn-gui.exe"
    echo [OK] Da khoi chay OpenVPN GUI tu Program Files!
) else if exist "C:\Program Files (x86)\OpenVPN\bin\openvpn-gui.exe" (
    start "" "C:\Program Files (x86)\OpenVPN\bin\openvpn-gui.exe"
    echo [OK] Da khoi chay OpenVPN GUI tu Program Files (x86)!
) else (
    echo [!] Khong tim thay OpenVPN GUI o thu muc mac dinh. Vui long mo thu cong.
)
timeout /t 3 >nul
goto MENU

:SSH_HQ_GW
cls
echo [*] Dang ket noi SSH toi HQ Gateway (172.16.1.10)...
ssh student@172.16.1.10
goto MENU

:SSH_BR_GW
cls
echo [*] Dang ket noi SSH toi Branch Gateway (172.16.1.20)...
ssh student@172.16.1.20
goto MENU

:SSH_HQ_SERVER
cls
echo [*] Dang ket noi SSH toi HQ Internal Server (192.168.10.50)...
echo [!] Yeu cau may nay da ket noi VPN thanh cong truoc khi SSH.
ssh student@192.168.10.50
goto MENU

:BENCHMARK_TEST
cls
echo ==============================================================================
echo          DO TOC DO TAI TAI LIEU MAT 1MB QUA DUONG HAM BAO MAT
echo ==============================================================================
echo.
echo [*] Dang gui request tai file http://192.168.10.50/files/benchmark-payload-1mb.dat...
powershell -Command "$start = Get-Date; try { Invoke-WebRequest -Uri 'http://192.168.10.50/files/benchmark-payload-1mb.dat' -OutFile '$env:TEMP\benchmark.dat' -UseBasicParsing; $duration = ((Get-Date) - $start).TotalSeconds; $speed = [math]::Round(1.0 / $duration, 2); Write-Host \"`n[THANH CONG] Da tai xong file 1MB trong $duration giay! (Toc do: $speed MB/s)\" -ForegroundColor Green } catch { Write-Host \"`n[THAT BAI] Khong the tai file. Hay kiem tra ket noi VPN!\" -ForegroundColor Red }"
echo.
pause
goto MENU

:EXIT_SCRIPT
echo.
echo [*] Cam on ban da su dung VPN Management Utility. Tam biet!
timeout /t 2 >nul
exit /b 0

