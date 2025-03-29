function Invoke-QueryWID ($query_statement) {
    $server_instance = "np:\\.\pipe\MICROSOFT##WID\tsql\query"
    return Invoke-Sqlcmd -Query $query_statement -ServerInstance $server_instance
}

function ConvertTo-MiB ($number_to_convert) {
    return [math]::round($number_to_convert / 1024, 2)
}

function Get-Computers-FailedOrNeeded($target_group) {
    $updates = Get-WsusComputer -ComputerUpdateStatus FailedOrNeeded -ComputerTargetGroups $target_group 
    # if not polish version of WSUS, change to yours message
    $message = "Brak dostępnych komputerów."
    if($updates -like $message) { return 0 }
    else { return $updates.Count }
}

Function Get-Computers-AllAndOld($target_group) {
    $report_result = @{}
    $all_computers = Get-WsusComputer -ComputerTargetGroups $target_group
    $report_result["all_computers"] = $all_computers.Count
    $report_result["old_computers"] = ($all_computers | Where-Object {
        if($_.LastReportedStatusTime){
            (New-TimeSpan -Start $_.LastReportedStatusTime -End (Get-Date)).Days -ge 30
        }
    }).Count
    return $report_result
}

function Get-Computers-ToUpdateList($target_group) {
    $list_computers = (Get-WsusComputer -ComputerUpdateStatus FailedOrNeeded -ComputerTargetGroups $target_group).FullDomainName
    if(-not $list_computers)  { $list_computers = "All updated." }
    return $list_computers
}

function Test-Port($port) {
    $tested_port = Test-NetConnection -Port $port -ComputerName $env:COMPUTERNAME -InformationLevel Quiet
    return $(if($tested_port) {"Open"} Else {"Close"})
}

function Get-Certificate($cert_name) {
    $check_result = @{}
    $check_result["expiration_date"] = (Get-ChildItem -Path Cert:\LocalMachine\My -Recurse | Where-Object { $_.DnsName -eq $cert_name }).NotAfter
    $check_result["days_to_expire"] = (New-TimeSpan -Start (Get-Date) -End $check_result["expiration_date"]).Days
    $check_result["expiration_date"] = $check_result["expiration_date"].ToString("dd-MM-yyyy")
    return $check_result
}

function Get-Servers-UpdateList($server_group) {
    $language = "pl"
    $list_servers_updates_query = "
        USE SUSDB;
        SELECT
            ct.FullDomainName,
            pcpl.Title
        FROM
            dbo.tbComputerTarget ct
        JOIN
            dbo.tbUpdateStatusPerComputer uspc ON ct.TargetID = uspc.TargetID
        JOIN
            dbo.tbTargetInTargetGroup tgi ON ct.TargetID = tgi.TargetID
        JOIN
            dbo.tbTargetGroup tg ON tgi.TargetGroupID = tg.TargetGroupID
        JOIN
	        dbo.tbUpdate u ON u.LocalUpdateID = uspc.LocalUpdateID
        JOIN
	        dbo.tbPreComputedLocalizedProperty pcpl ON pcpl.UpdateID = u.UpdateID 
        WHERE
            tg.Name = '$server_group'
            AND uspc.SummarizationState = 2
	        AND pcpl.ShortLanguage = '$language';
    "
    $queryResult = Invoke-QueryWID($list_servers_updates_query)
    if(-not $queryResult) { return "All updated" }
    else {
        $sort_table = @{}
        foreach ($row in $queryResult) {
            $server_name = $row.FullDomainName
            $server_updates = $row.Title
            if (-not $sort_table.ContainsKey($server_name)) {
                $sort_table[$server_name] = @()
            }
            $sort_table[$server_name] += $server_updates
        }
        return $sort_table
    }
}

function Get-Susdb-Information {
    $information_susdb = @{}
    $susdb_query = Invoke-QueryWID("SELECT size,state_desc FROM sys.master_files WHERE name like 'SUSDB%';")
    $information_susdb["size_susdb"] = ConvertTo-MiB($susdb_query[0][0])
    $information_susdb["size_susdb_log"] = ConvertTo-MiB($susdb_query[1][0])
    $information_susdb["wid_state"] = $susdb_query[0][1]
    return $information_susdb
}

$wsus_server_name = "wsus.mycompany.local"
$computer_group = "WindowsPC"
$server_group = "WindowsServers"
$information_susdb = Get-Susdb-Information
$check_certificate = Get-Certificate($wsus_server_name)
$report_computers = Get-Computers-AllAndOld($computer_group)
$report_servers = Get-Computers-AllAndOld($server_group)

$data_table = @{
    "NumberComputers" = $report_computers["all_computers"]
    "NumberOldComputers" = $report_computers["old_computers"]
    "NumberServers" = $report_servers["all_computers"]
    "NumberOldServers" = $report_servers["old_computers"]
    "NumberUpdates" = (Get-WsusUpdate -Classification All -Approval Unapproved).Count
    "NumberComputersToUpdate" = Get-Computers-FailedOrNeeded($computer_group)
    "NumberServersToUpdate" = Get-Computers-FailedOrNeeded($server_group)
    "SizeSUSDB" = $information_susdb["size_susdb"]
    "SizeSUSDB_LOG" = $information_susdb["size_susdb_log"]
    "SUSDBstate" = $information_susdb["wid_state"]
    "Port8530" = Test-Port(8530)
    "Port8531" = Test-Port(8531)
    "CertificateValidUntil" = $check_certificate["expiration_date"]
    "CertificateValidDays" = $check_certificate["days_to_expire"]
    "ListServersToUpdate" = Get-Servers-UpdateList($server_group)
    "ServiceIISstate" = (Get-Service "W3SVC").Status
    "ServiceWSUSstate" = (Get-Service "WSUSService").Status
    "ServiceWIDstate" = (Get-Service "MSSQL`$MICROSOFT##WID").Status
    "LastSynchronization" = (Get-WsusServer -Name $wsus_server_name -PortNumber 8531 -UseSsl).GetSubscription().GetLastSynchronizationInfo().Result
}

$data_table | ConvertTo-Json
