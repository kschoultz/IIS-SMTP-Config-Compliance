# SMTP Relay IPGrant Script

$Networkip =@();
$Networks = Get-WmiObject Win32_NetworkAdapterConfiguration | ? {$_.IPEnabled};
foreach($Network in $Networks)  {$Networkip = $Network.IpAddress[0]};

Write-Host "Networkip: $Networkip";

$ipblock= @(24,0,0,128,
32,0,0,128,
60,0,0,128,
68,0,0,128,
1,0,0,0,
76,0,0,0,
0,0,0,0,
0,0,0,0,
1,0,0,0,
0,0,0,0,
2,0,0,0,
1,0,0,0,
4,0,0,0,
0,0,0,0,
76,0,0,128,
0,0,0,0,
0,0,0,0,
0,0,0,0,
0,0,0,0,
255,255,255,255)

$ipList = @()
$octet = @()
##$connectionips=$arg[0]       
$ipList = "127.0.0.1"
$octet += $ipList.Split(".")
$octet += $Networkip.Split(".")

Write-Host "octet: $octet"

$ipblock[36] +=2 
$ipblock[44] +=2;

Write-Host "IPBlock{36}: " $ipblock[36];
Write-Host "IPBlock{44}: "  $ipblock[44];

Write-Host "IPBlock: $ipblock";

$ipblock += $octet;
Write-Host "IPBlock-Revised: $ipblock";

$smtpserversetting = get-wmiobject -namespace root\MicrosoftIISv2 -computername localhost -Query "Select * from IIsSmtpServerSetting"
##$ipblock += $octet

####$smtpserversetting.AuthBasic=1
$smtpserversetting.RelayIpList = $ipblock
$smtpserversetting.put()