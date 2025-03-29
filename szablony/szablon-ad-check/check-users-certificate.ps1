$ou = "OU=Users,OU=MYCOMPANY,DC=mycompany,DC=local"
$daysToCheck = 15
$dateCurrent = Get-Date
$users = @()

Get-ADUser -Filter * -SearchBase $ou -Properties "UserPrincipalName","UserCertificate","userAccountControl" | ForEach-Object {
    if([int]$_.userAccountControl -eq 512){
        $firstCert = $_.UserCertificate | Select-Object -First 1
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$firstCert
        if ($cert.NotAfter -le $dateCurrent.AddDays($daysToCheck) -and $cert.NotAfter){
            $userInfo = [PSCustomObject]@{
                UserPrincipalName = $_.UserPrincipalName
                ExpirationDate = $cert.NotAfter
            }
            $users += $userInfo
        }
    }
}

$users = $users | Sort-Object ExpirationDate -Descending
$users | ConvertTo-Html -Property UserPrincipalName, ExpirationDate -Fragment