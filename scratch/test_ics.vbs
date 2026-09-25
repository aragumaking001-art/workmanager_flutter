Set m = CreateObject("HNetCfg.HNetShare")
Set conns = m.EnumEveryConnection
For Each c In conns
    Set p = m.NetConnectionProps(c)
    WScript.Echo "Name: " & p.Name
Next
