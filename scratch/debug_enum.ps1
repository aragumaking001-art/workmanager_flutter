$m = New-Object -ComObject HNetCfg.HNetShare
$conns = $m.EnumEveryConnection
Write-Host "Count:" $conns.Count
foreach ($c in $conns) {
    $p = $m.NetConnectionProps.Invoke($c)
    Write-Host "Name:" $p.Name " GUID:" $p.Guid
}
