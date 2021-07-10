$time = Get-Date
$hr = $time.TimeOfDay.Hours
$min = $time.TimeOfDay.Minutes
$day = $time.DayOfYear
$yr = $time.Year

$ip = "127.0.0.1"
$port = 514
$address = [system.net.IPAddress]::Parse($ip)
$server = New-Object System.Net.IPEndPoint $address, $port

$new_socket = [System.Net.Sockets.AddressFamily]::InterNetwork
$socket_type = [System.Net.Sockets.SocketType]::Dgram
$protocol = [System.Net.Sockets.ProtocolType]::UDP
$sock = New-Object System.Net.Sockets.Socket $new_socket, $socket_type, $protocol
$sock.TTL = 90

$log_pool = @()
Get-WinEvent -ListLog * | ForEach-Object {
        if ($_.RecordCount -gt 0) {
                $log_pool += $_.LogName
        }
}

$current_time = Get-Date
$current_hr  = $current_time.TimeOfDay.Hours
$current_min = $current_time.TimeOfDay.Minutes
$current_day = $current_time.DayOfYear
$current_year = $current_time.Year

$time = $current_time;
$previous_min = $time.TimeOfDay.Minutes - 1
$hour = $time.TimeOfDay.Hours
$day = $time.DayOfYear
$year = $time.Year
if ($previous_min -eq -1) {
        $previous_min = 59;
} ElseIf ($($hour - 1) -eq -1)  {
        $hour = 23;
}

$event_pool = @()
$log_pool | ForEach-Object {
    Get-WinEvent -LogName "$_" -MaxEvents 20 | Sort-Object TimeCreated | Where-Object { $_.TimeCreated.Hour -eq $hour -and $_.TimeCreated.Minute -eq $previous_min -and $_.TimeCreated.DayOfYear -eq $day -and $_.TimeCreated.Year -eq $year  } | ForEach-Object {
        $event_pool += $_
    }
}

if ($event_pool.Count -ne 0) {
    $sleepyTime = Get-Random(1..10)
    sleep $sleepytime
    $event_pool = $event_pool | Sort-Object { $_.TimeCreated }
    $event_pool | ForEach-Object {
        $message = $_.Message
        $event_id = $_.Id
        #get acount name from authentication logs
        if ($event_id -eq 4672 -or $event_id -eq 4634) {
            $user = $($($message | findstr Name) -split "`t")[3]
        } ElseIf ($event_id -eq 4624 -or $event_id -eq 4648) {
            $user = $($($($($message | findstr Name) -split "`n")[1]) -split "`t")[3]
        } Else {
            $user = $_.UserId
            if (!$user) {
            $user = "n/a"
            }
        }
        $message = $message -split "`n"
	$message = $message[0]
	$message = $message -replace('"',"'")
        $source = $_.ProviderName
        $hname = $_.MachineName
        $severity = $_.LevelDisplayName
        $timestamp = $_.TimeCreated
        $log = -join $('HostName:"',$hname,'" TimeStamp:"',$timestamp,'" LogType:"',$source,'" ','SrcUser:"',$user,'" Message:"',$message,'" EventID:"',$event_id,'" Severity:"',$severity,'"')
        $Enc = [System.Text.Encoding]::ASCII
        $Buffer = $Enc.GetBytes($log)
        $sock.Connect($server)
        $sendit = $sock.Send($Buffer)
    }
}

Remove-Variable -Name * -ErrorAction SilentlyContinue
[gc]::collect()
