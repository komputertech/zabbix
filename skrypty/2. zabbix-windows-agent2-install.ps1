<# ********************************
* https://github.com/komputertech *
******************************** #>

# Variables
$ZbxLine = '7.0'
$ZbxPatch = '3'
$ZbxVersion = $ZbxLine + '.' + $ZbxPatch

$ComputerHostname = $env:COMPUTERNAME
$ComputerIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -ne 'Loopback Pseudo-Interface 1' }).IPAddress | Select-Object -First 1

$ParamZbxSrvIP = '192.168.117.2'
$ParamTimeout = '5'
$ParamAllowSystemRun = 'ALLOWDENYKEY=`"AllowKey=system.run[*]`"'
$ParamTlsPskIdentity = 'PSK' + (($ComputerIP.Split('.') | ForEach-Object { $_.PadLeft(3, '0') }) -join '').Substring(6)
$ParamTlsPskKey = '1f87b595725ac58dd977beef14b97461a7c1045b9a1c963065002c5473194952'
$ParamTlsPskAll = "TLSCONNECT=psk TLSACCEPT=psk TLSPSKIDENTITY=$ParamTlsPskIdentity TLSPSKVALUE=$ParamTlsPskKey"

$UserDownloadFolder = [Environment]::GetFolderPath('UserProfile') + '\Downloads'
$InstallerFileName = 'zabbix_agent2-' + $ZbxVersion + '-windows-amd64-openssl.msi'

# Check if installer is downloaded, if not, download it
Write-Host "Try to download Zabbix Agent2, line $ZbxLine patch $ZbxPatch"
$InstallerOutput = $UserDownloadFolder + '\' + $InstallerFileName
if (Test-Path -Path $InstallerOutput -PathType Leaf) {
    Write-Host "Already downloaded"
} else {
    $InstallerURL = 'https://cdn.zabbix.com/zabbix/binaries/stable/' + $ZbxLine + '/' + $ZbxVersion + '/' + $InstallerFileName
    try {
        Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerOutput
        Write-Host "File downloaded successfully to $InstallerOutput" -ForegroundColor Green
    } catch {
        Write-Host "Something goes wrong" -ForegroundColor Red
        exit(0)
    }
}

# Backup configuration files
Write-Host "Copy configuration file"
@('C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf', 'C:\Program Files\Zabbix Agent\zabbix_agentd.conf') | ForEach-Object {
    if (Test-Path -Path $_ -PathType Leaf) {
        $fileName = Split-Path -Path $_ -Leaf
        if (Test-Path -Path (Join-Path -Path $UserDownloadFolder -ChildPath ($fileName + '.old')) -PathType Leaf) {
            Write-Host "Backup exist, remove it first" -ForegroundColor Red
            exit(0)
        }
        Copy-Item -Path $_ -Destination (Join-Path -Path $UserDownloadFolder -ChildPath ($fileName + '.old'))
        Write-Host "Configuration file saved" -ForegroundColor Green
    } else {
        Write-Host "Configuration file not found"
    }
}

# Cleaning old installation
Write-Host "Uninstalling previous version of Zabbix Agent"
$PreviousVersions = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like 'Zabbix Agent*' }
if ($PreviousVersions) {
    foreach ($Version in $PreviousVersions) {
        $MsiExecArgs = "/x $($Version.IdentifyingNumber) /qn"
        $StartProcess = Start-Process msiexec -ArgumentList $MsiExecArgs -PassThru -Wait -NoNewWindow
        if ($StartProcess.ExitCode -eq 0) {
            Write-Host "Previous version uninstalled successfully" -ForegroundColor Green
        } else {
            Write-Host "Uninstallation failed with exit code $($StartProcess.ExitCode)" -ForegroundColor Red
            exit(0)
        }
    }
}
@('Zabbix Agent', 'Zabbix Agent 2') | ForEach-Object { 
    $ServiceZabbix = Get-Service -Name $_ -ErrorAction SilentlyContinue
    if ($ServiceZabbix) {
        sc.exe delete $_
        Write-Host "Service $_ remove successfully" -ForegroundColor Green
    }
    $RegistryZabbix = 'HKLM:\SYSTEM\ControlSet001\Services\EventLog\Application\' + $_
    if (Test-Path -Path $RegistryZabbix) {
        Remove-Item -Path $RegistryZabbix -Recurse
        Write-Host "Registry $_ remove successfully" -ForegroundColor Green
    }
}

# Installation
Write-Host "Try to install"
$LogFile = "$UserDownloadFolder\zabbix_install_log.txt"
if (-not (Test-Path -Path $LogFile)) {
    Write-Host "Installation log was not created." -ForegroundColor Red
    exit 0
}
$MsiParamAll = "$ParamAllowSystemRun ENABLEPATH=1 HOSTNAME=$ComputerHostname SERVER=$ParamZbxSrvIP TIMEOUT=$ParamTimeout $ParamTlsPskAll"
$MsiArgs = "/l*v $LogFile /i $InstallerOutput /qn $MsiParamAll"
$StartProcess = Start-Process msiexec -ArgumentList $MsiArgs -PassThru -Wait -NoNewWindow
if ($StartProcess.ExitCode -eq 0) {
    Write-Host "Installation completed successfully" -ForegroundColor Green
} else {
    Write-Host "Installation failed with exit code $($StartProcess.ExitCode)" -ForegroundColor Red
}