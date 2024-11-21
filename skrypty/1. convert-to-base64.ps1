<# ********************************
* https://github.com/komputertech *
******************************** #>

$GetContent = Get-Content ".\TestScript.ps1"
$Base64Code = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($GetContent))
write-host $Base64Code

# Zabbix
# system.run[powershell.exe -noprofile -nologo -encodedCommand "paste base64 output in here"]