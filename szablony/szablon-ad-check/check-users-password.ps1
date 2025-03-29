$ou = "OU=Users,OU=MYCOMPANY,DC=mycompany,DC=local"
$daysToCheck = 8
$daysPasswordIsValid = 90

$dateCurrent = Get-Date
$dateExpireWarning = ($dateCurrent.AddDays($daysToCheck)).ToString("MM/dd/yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
$users = @()

Get-ADUser -Filter * -SearchBase $ou -Properties "UserPrincipalName", "pwdLastSet", "userAccountControl" | ForEach-Object {
    if([int]$_.userAccountControl -eq 512){
        $userPasswordLastSet = $_.pwdLastSet
        $userPasswordExpireDate = ([datetime]::FromFileTime($userPasswordLastSet)).AddDays($daysPasswordIsValid)
        $userPasswordExpireDays = ($userPasswordExpireDate - $dateCurrent).Days
        if($userPasswordExpireDate -le $dateExpireWarning){
            $userInfo = [PSCustomObject]@{
                UserPrincipalName = $_.UserPrincipalName
                PasswordExpireDate = $userPasswordExpireDate
                DaysUntilExpire = $userPasswordExpireDays
            }
            $users += $userInfo
        }
    }
}

$users = $users | Sort-Object DaysUntilExpire -Descending
$users | ConvertTo-Html -Property UserPrincipalName, PasswordExpireDate, DaysUntilExpire -Fragment