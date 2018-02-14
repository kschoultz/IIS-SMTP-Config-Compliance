# Initialize script variables.
$b_IS_SMTP_CONNECTION_LOOPBACK_IP_SET = 0; #FALSE
$b_IS_SMTP_CONNECTION_PRIMARY_IP_SET = 0; #FALSE


function ValidateSMTPConnectionSettings ($connectionips) {  
    Get-CimInstance -Namespace "root\MicrosoftIISv2" -Class "IIsIPSecuritySetting" -Filter "Name ='SmtpSvc/1'"

    # Create an instance of the SMTP Service for upcoming alterations.
    $iisObject = new-object System.DirectoryServices.DirectoryEntry("IIS://localhost/SmtpSvc/1");
    $ipSec = $iisObject.Properties["IPSecurity"].Value;

    # Set the Grant by Default setting to FALSE.
    [Object[]] $grantByDefault = @();
    $grantByDefault += , $false; # <<< We're setting it to false.
    # Set and save the GrantByDefault setting to the SMTP service.
    $bindingFlags = [Reflection.BindingFlags] "Public, Instance, SetProperty";
    $ipSec.GetType().InvokeMember("GrantByDefault", $bindingFlags, $null, $ipSec, $grantByDefault);
    $iisObject.Properties["IPSecurity"].Value = $ipSec;
    $iisObject.CommitChanges();

    # Establish the array of IP addresses to be granted access to the SMTP service.
    # Obtain the primary public IP address.
    ###$connectionips =@();
    ###$Networks = Get-WmiObject Win32_NetworkAdapterConfiguration | ? {$_.IPEnabled};
    ###foreach($Network in $Networks)  {$connectionips = $Network.IpAddress[0]};

    # Initialize the IP Address array by adding the localhost loopback address.
    $connectionipbuild=@("127.0.0.1,255.255.255.255;");
    $ipArray=$connectionips.split(",");
    # Now we add the primary public IP Address to the array.
    foreach ($ip in $ipArray) {$connectionipbuild +=$ip+",255.255.255.255;";}

    # Create the IP Array list that be passed to the update method.
    $ipList = $ipList + $connectionipbuild;

    # This is important, we need to pass an object array of one element containing our ipList array
    [Object[]] $ipArray = @();
    $ipArray += , $ipList;

    # Update the Connection IP address list with the values from the IP address array.
    $bindingFlags = [Reflection.BindingFlags] "Public, Instance, SetProperty";
    $ipList = $ipSec.GetType().InvokeMember("IPGrant", $bindingFlags, $null, $ipSec, $ipArray);
    $iisObject.Properties["IPSecurity"].Value = $ipSec;
    $iisObject.CommitChanges();

    Get-CimInstance -Namespace "root\MicrosoftIISv2" -Class "IIsIPSecuritySetting" -Filter "Name ='SmtpSvc/1'";
}

# Obtain the primary public IP address
$Networks = Get-WmiObject Win32_NetworkAdapterConfiguration | ? {$_.IPEnabled};
foreach($Network in $Networks)  {$primaryIPAddress = $Network.IpAddress[0]};

$currentIPGrant = Get-CimInstance -Namespace "root\MicrosoftIISv2" -Class "IIsIPSecuritySetting" -Filter "Name ='SmtpSvc/1'" | % {$_.IPGrant};
Write-Host "currentIPGrantArray: $currentIPGrant";
$ipGrantArray = $currentIPGrant.split('[\r\n]');
foreach ($ipPair in $ipGrantArray) {
   $ipPair = $ipPair.replace(' ','');
   $singleIPAddress = $ipPair.split(",");
   foreach ($ip in $singleIPAddress) {

      SWITCH ($ip) {
        "127.0.0.1" {Write-Host "Loopback found: $ip";
                     $b_IS_SMTP_CONNECTION_LOOPBACK_IP_SET = 1; # Loopback IP address found.
                    }
        $primaryIPAddress {Write-Host "Primary IP found: $ip";
                           $b_IS_SMTP_CONNECTION_PRIMARY_IP_SET = 1; # Primary IP address found.
                          }
        DEFAULT {Write-Host "Single IP: $ip"; # Neither loopback or primary IP address found.
                }
       }
   }
 }


Write-Host "b_IS_SMTP_CONNECTION_LOOPBACK_IP_SET: $b_IS_SMTP_CONNECTION_LOOPBACK_IP_SET";
Write-Host "b_IS_SMTP_CONNECTION_PRIMARY_IP_SET: $b_IS_SMTP_CONNECTION_PRIMARY_IP_SET";


ValidateSMTPConnectionSettings $primaryIPAddress;