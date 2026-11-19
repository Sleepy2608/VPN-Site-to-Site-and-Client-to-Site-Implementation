@echo off
chcp 65001 >nul
title VPN Site-to-Site & Client-to-Site Management Utility
color 0A

:: =============================================================================
:: quick-setup.bat: Kịch bản kiểm tra và điều khiển nhanh hệ thống VPN Lab
:: Dành cho môi trường Windows (Remote Worker 172.16.1.100)
:: Hỗ trợ cả mô hình 3 Máy Ảo (Khuyến nghị) và 5 Máy Ảo
:: =============================================================================

:MENU
cls
echo ==============================================================================
echo       VPN SITE-TO-SITE & CLIENT-TO-SITE LAB MANAGEMENT CONTROLLER
echo ==============================================================================
echo.
echo   [1] Kiem tra ket noi mang (Ping Server, Client-Linux va Tunnel Gateway)
echo   [2] Mo Cong Thong Tin Noi Bo HQ Web Portal (http://10.8.0.1 hoac 192.168.10.1)
echo   [3] Kiem tra bang dinh tuyen may khach (Route Print Split-Tunnel)
echo   [4] Chay Trace Route toi May chu qua VPN Tunnel (tracert 10.8.0.1)
echo   [5] Khoi dong OpenVPN GUI tren Windows
echo   [6] SSH toi VM-Server (ssh student@172.16.1.10 hoac 10.8.0.1)
echo   [7] SSH toi VM-Client-Linux (ssh student@172.16.1.20 hoac 10.8.0.2)
echo   [8] SSH toi HQ Internal IP (ssh student@192.168.10.1)
echo   [9] Do toc do tai file 1MB bao mat tu VPN Server (AES-256-GCM)
echo   [0] Thoat chuong trinh
echo.
echo ==============================================================================
set /p CHOICE="Nhap lua chon cua ban [0-9]: "

if "%CHOICE%"=="1" goto PING_TEST
if "%CHOICE%"=="2" goto OPEN_PORTAL
if "%CHOICE%"=="3" goto ROUTE_CHECK
if "%CHOICE%"=="4" goto TRACERT_TEST
if "%CHOICE%"=="5" goto LAUNCH_OPENVPN
if "%CHOICE%"=="6" goto SSH_SERVER
if "%CHOICE%"=="7" goto SSH_CLIENT_LINUX
if "%CHOICE%"=="8" goto SSH_HQ_LAN
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
echo [*] 1. Ping VM-Server qua mang WAN (172.16.1.10)...
ping -n 3 172.16.1.10
echo.
echo [*] 2. Ping Client Linux qua mang WAN (172.16.1.20)...
ping -n 3 172.16.1.20
echo.
echo [*] 3. Ping OpenVPN Tunnel Server (10.8.0.1)...
ping -n 3 10.8.0.1
echo.
echo [*] 4. Ping Client Linux qua Tunnel VPN (10.8.0.2)...
ping -n 3 10.8.0.2
echo.
echo [*] 5. Ping HQ Internal LAN (192.168.10.1 hoac 192.168.10.50)...
ping -n 3 192.168.10.1
echo.
echo ==============================================================================
echo [!] Neu ping 10.8.0.1 hoac 192.168.10.1 thanh cong: Ban da ket noi VPN an toan!
echo [!] Neu ping that bai: Hay bat ket noi OpenVPN GUI hoac kiem tra IP.
echo ==============================================================================
pause
goto MENU

:OPEN_PORTAL
cls
echo [*] Dang mo trinh duyet truy cap Cong thong tin noi bo HQ...
echo [*] Thu nghiem dia chi VPN Tunnel: http://10.8.0.1 ...
start http://10.8.0.1
echo [*] Da mo trinh duyet thanh cong!
timeout /t 2 >nul
goto MENU

:ROUTE_CHECK
cls
echo ==============================================================================
echo             KIEM TRA BANG DINH TUYEN (ROUTING TABLE CHECK)
echo ==============================================================================
echo.
echo [*] Danh sach route huong toi dai mang noi bo HQ va Tunnel VPN:
echo.
route print -4 | findstr "192.168.10. 10.8.0. Network"
echo.
echo ==============================================================================
echo [!] Ky vong Split-Tunneling: 192.168.10.0 hoac 10.8.0.0 tro qua Gateway 10.8.0.1
echo ==============================================================================
pause
goto MENU

:TRACERT_TEST
cls
echo ==============================================================================
echo         XAC NHAN DUONG DI GOI TIN QUA VPN TUNNEL (TRACEROUTE)
echo ==============================================================================
echo.
echo [*] Dang chay tracert toi Tunnel VPN Server 10.8.0.1 (Vui long cho vai giay)...
tracert -d 10.8.0.1
echo.
echo ==============================================================================
echo [!] Ky vong: Goi tin di truc tiep vao dai 10.8.0.x (Khong lo IP WAN 172.16.1.x)
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

:SSH_SERVER
cls
echo [*] Dang ket noi SSH toi VM-Server (172.16.1.10)...
ssh student@172.16.1.10
goto MENU

:SSH_CLIENT_LINUX
cls
echo [*] Dang ket noi SSH toi VM-Client-Linux (172.16.1.20)...
ssh student@172.16.1.20
goto MENU

:SSH_HQ_LAN
cls
echo [*] Dang ket noi SSH toi HQ Internal LAN (192.168.10.1)...
ssh student@192.168.10.1
goto MENU

:BENCHMARK_TEST
cls
echo ==============================================================================
echo          DO TOC DO TAI TAI LIEU MAT 1MB QUA DUONG HAM BAO MAT
echo ==============================================================================
echo.
echo [*] Dang gui request tai file http://10.8.0.1/files/benchmark-payload-1mb.dat...
powershell -Command "$start = Get-Date; try { $res = Invoke-WebRequest -Uri 'http://10.8.0.1/files/benchmark-payload-1mb.dat' -OutFile '$env:TEMP\benchmark.dat' -UseBasicParsing -ErrorAction Stop; $duration = ((Get-Date) - $start).TotalSeconds; $speed = [math]::Round(1.0 / $duration, 2); Write-Host \"`n[THANH CONG] Da tai xong file 1MB trong $duration giay! (Toc do: $speed MB/s)\" -ForegroundColor Green } catch { try { $res = Invoke-WebRequest -Uri 'http://192.168.10.1/files/benchmark-payload-1mb.dat' -OutFile '$env:TEMP\benchmark.dat' -UseBasicParsing; $duration = ((Get-Date) - $start).TotalSeconds; $speed = [math]::Round(1.0 / $duration, 2); Write-Host \"`n[THANH CONG] Da tai xong qua LAN IP trong $duration giay! (Toc do: $speed MB/s)\" -ForegroundColor Green } catch { Write-Host \"`n[THAT BAI] Khong the tai file. Hay kiem tra ket noi VPN!\" -ForegroundColor Red } }"
echo.
pause
goto MENU

:EXIT_SCRIPT
echo.
echo [*] Cam on ban da su dung VPN Management Utility. Tam biet!
timeout /t 2 >nul
exit /b 0