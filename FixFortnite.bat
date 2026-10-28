@echo off
REM ============================================================
REM  Fortnite Easy Anti-Cheat repair tool
REM  ASCII-only batch section (no chcp here - it breaks parsing)
REM ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Continue';$t='#POWER'+'SHELL_PAYLOAD';$s=(Get-Content -Raw -Encoding UTF8 '%~f0') -split $t;iex $s[1]"

echo.
pause
exit /b
#POWERSHELL_PAYLOAD
$ErrorActionPreference = 'Continue'
chcp.com 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Say($m){ Write-Host $m }

$eacDir = 'C:\Program Files (x86)\EasyAntiCheat_EOS'
$svcKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\EasyAntiCheat_EOS'
$drvKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\EasyAntiCheat_EOSSys'
$setup  = 'C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\EasyAntiCheat\EasyAntiCheat_EOS_Setup.exe'
$kill   = @('FortniteClient-Win64-Shipping_EAC_EOS','FortniteClient-Win64-Shipping','FortniteBootstrapper',
            'FortniteLauncher','EpicOnlineServicesUserHelper','EpicOnlineServicesHost','EpicOnlineServicesUIHelper',
            'EasyAntiCheat_EOS','EpicWebHelper','EpicGamesLauncher')

Say ''
Say '=============================================='
Say '  Fortnite Easy Anti-Cheat repair'
Say '=============================================='
Say ''

Say '[1/6] Closing leftover Fortnite / EAC / EOS processes...'
$n = 0
foreach($p in $kill){
    foreach($pr in (Get-Process -Name $p -ErrorAction SilentlyContinue)){
        Stop-Process -Id $pr.Id -Force -ErrorAction SilentlyContinue
        $n++
    }
}
Say "      processes closed: $n"
Start-Sleep -Seconds 3

Say '[2/6] Removing EasyAntiCheat_EOS service...'
Stop-Service EasyAntiCheat_EOS -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
sc.exe delete EasyAntiCheat_EOS 2>&1 | Out-Null
Start-Sleep -Seconds 2
if(Test-Path $svcKey){ Remove-Item $svcKey -Recurse -Force -ErrorAction SilentlyContinue }
if(Test-Path 'HKLM:\SOFTWARE\WOW6432Node\EasyAntiCheat_EOS'){
    Remove-Item 'HKLM:\SOFTWARE\WOW6432Node\EasyAntiCheat_EOS' -Recurse -Force -ErrorAction SilentlyContinue }
Say '      service removed'

Say '[3/6] Wiping EAC files and session cache...'
if(Test-Path $eacDir){ Remove-Item $eacDir -Recurse -Force -ErrorAction SilentlyContinue }
if(Test-Path "$env:APPDATA\EasyAntiCheat"){ Remove-Item "$env:APPDATA\EasyAntiCheat" -Recurse -Force -ErrorAction SilentlyContinue }
Say '      files wiped'

Say '[4/6] Installing Easy Anti-Cheat fresh...'
if(-not (Test-Path $setup)){
    Say '      ERROR: Fortnite not found at expected path.'
    Say '      Keep this script inside the Fortnite folder tree.'
    return
}
$p = Start-Process $setup -ArgumentList 'install','prod-fn' -PassThru -Wait -NoNewWindow
Say "      setup exit code: $($p.ExitCode)"
if($p.ExitCode -ne 0){ Say '      WARNING: setup returned an error' }

Say '[5/6] Restoring driver + Attestation registration...'
if(-not (Test-Path $setup)){ return }
if(-not (Test-Path "$svcKey\Attestation")){ New-Item "$svcKey\Attestation" -Force | Out-Null }
if(-not (Test-Path $drvKey)){
    New-Item $drvKey -Force | Out-Null
    New-ItemProperty $drvKey -Name 'ImagePath'    -Value '\??\C:\Program Files (x86)\EasyAntiCheat_EOS\EasyAntiCheat_EOS.sys' -PropertyType String -Force | Out-Null
    New-ItemProperty $drvKey -Name 'Type'         -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty $drvKey -Name 'Start'        -Value 3 -PropertyType DWord -Force | Out-Null
    New-ItemProperty $drvKey -Name 'ErrorControl' -Value 1 -PropertyType DWord -Force | Out-Null
    Say '      driver registered (Start=3 demand)'
} else {
    Set-ItemProperty $drvKey -Name 'Start' -Value 3 -ErrorAction SilentlyContinue
    Say '      driver existed, Start forced to 3'
}

Say '[6/6] Verifying...'
$v = Start-Process $setup -ArgumentList 'verify-installation','prod-fn' -PassThru -Wait -NoNewWindow
if(Test-Path $eacDir){
    Get-ChildItem $eacDir -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $sig = (Get-AuthenticodeSignature $_.FullName).Status
        Say ("      {0,-26} {1,10}  sig: {2}" -f $_.Name, $_.Length, $sig)
    }
} else { Say '      ERROR: EAC folder missing' }

$mustReboot = $false
$drv = Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'EasyAntiCheat_EOSSys' }
if($drv){
    Say ("      driver: " + $drv.Name + "  state=" + $drv.State + "  start=" + $drv.StartMode)
    if($drv.State -match 'Stop Pending'){ $mustReboot = $true }
} else { Say '      driver: not registered (loads at game start)' }

Say ''
Say '=============================================='
if($v.ExitCode -eq 0){ Say '  EAC installed correctly.' }
else { Say "  verify-installation returned $($v.ExitCode)" }
if($mustReboot){
    Say ''
    Say '  DRIVER STUCK IN "Stop Pending"'
    Say '  This lives in the Windows kernel and is'
    Say '  cleared ONLY by a reboot. Reinstalling EAC'
    Say '  will not fix it. A reboot is REQUIRED.'
}
Say '=============================================='
Say ''
Say '  Next steps:'
Say '   1. REBOOT the computer (mandatory if noted above)'
Say '   2. Launch Fortnite right after boot'
Say '   3. If error 20006 returns - run this file again'
Say ''

$ans = Read-Host '  Reboot now? (Y/N)'
if($ans -match '^[Yy]'){
    Say '  Rebooting...'
    Start-Sleep -Seconds 3
    shutdown.exe /r /t 0
} else {
    Say '  OK, reboot whenever convenient.'
}