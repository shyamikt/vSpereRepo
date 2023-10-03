do { New-Object System.Net.Sockets.TcpClient("192.168.8.1", 443) } until ( ($_).connected -eq $true)
