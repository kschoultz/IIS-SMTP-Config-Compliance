## IIS_InstallationScript.ps1
##
## This PowerShell script is used to:
## * Determine if IIS is currently running.
## * If not running, determine if IIS has been installed and is simply down.
## * If not running and not installed, install IIS.
##
## Requirements:
## * An account with Administrator privileges are required to run this script.
##-------------------------------------------------------------------------------------------------------------------------------
## Usage Examples:
## Scenario #1: Will identify if IIS and SMTP services are installed and running. Will attempt to autostart them if they are not
##              currently running.
##              .\IIS_InstallationScript.ps1
##
## Scenario #2: If IIS Admin service is not installed, will automatically try to install all the required IIS Windows Features.
##              However, will not attempt to install the SMTP service (if not already installed).
##              .\IIS_InstallationScript.ps1 -AutoInstallIIS TRUE
##
## Scenario #3: If IIS Admin service is not installed, will automatically try to install all the required IIS Windows Features.
##              Will attempt to install, and automatically configure, the SMTP service (if not already installed).
##              .\IIS_InstallationScript.ps1 -AutoInstallIIS TRUE -AutoInstallSMTP TRUE
##-------------------------------------------------------------------------------------------------------------------------------
## History -
##-------------------------------------------------------------------------------------------------------------------------------
## Version: 1.0 | 10/16/2017 | Keith Schoultz | Original creation.
##-------------------------------------------------------------------------------------------------------------------------------

<# PARAMETERS #>
param (
       <# Used to determine if the server should be rebooted after installing features. #>
       [string]$AutoReboot = "FALSE",

       <# Used to determine if IIS should be restarted (if not running). #>
       [string]$AutoRestartIIS = "TRUE",
           
       <# Used to determine if SMTP should be restarted (if not running). #>
       [string]$AutoRestartSMTP = "TRUE",

       <# Used to determine if IIS/Web Services should be automatically insalled (if missing). #>
       [string]$AutoInstallIIS = "FALSE",

       <# Used to determine if individual IIS features should be automatically insalled (if missing). #>
       [string]$AutoInstallMissingIISFeatures = "FALSE",

       <# Used to determine if SMTP should be automatically insalled (if missing). #>
       [string]$AutoInstallSMTP = "FALSE",

       <# Used to determine if SMTP should be automatically configured (if installed and running). #>
       [string]$AutoConfigureSMTP = "FALSE"
       )

<#--- PARAMETERS INPUT VALIDATION BEGINS HERE. ---#>
$AutoReboot_Org=$AutoReboot;
$Autoboot="$AutoReboot".ToUpper();
IF ($AutoReboot -ne "TRUE" -and $AutoReboot -ne "FALSE"){
    Write-Host "ERROR! The -AutoReboot parameter you passed is an unacceptable value (TRUE/FALSE): $AutoReboot_Org" -foregroundcolor "red";
    Write-Host "Exiting...";
    Break;
      }

$AutoRestartIIS_Org=$AutoRestartIIS;
$AutoRestartIIS="$AutoRestartIIS".ToUpper();
IF ($AutoRestartIIS -ne "TRUE" -and $AutoRestartIIS -ne "FALSE"){
    Write-Host "ERROR! The -AutoRestartIIS parameter you passed is an unacceptable value (TRUE/FALSE): $AutoRestartIIS_Org" -foregroundcolor "red";
    Write-Host "Exiting...";
    Break;
      }

$AutoRestartSMTP_Org=$AutoRestartSMTP;
$AutoRestartSMTP="$AutoRestartSMTP".ToUpper();
IF ($AutoRestartSMTP -ne "TRUE" -and $AutoRestartSMTP -ne "FALSE"){
    Write-Host "ERROR! The -AutoRestartSMTP parameter you passed is an unacceptable value (TRUE/FALSE): $AutoRestartSMTP_Org" -foregroundcolor "red";
    Write-Host "Exiting...";
    Break;
      }

$AutoInstallIIS_Org=$AutoInstallIIS;
$AutoInstallIIS="$AutoInstallIIS".ToUpper();
IF ($AutoInstallIIS -ne "TRUE" -and $AutoInstallIIS -ne "FALSE"){
    Write-Host "ERROR! The -AutoInstallIIS parameter you passed is an unacceptable value (TRUE/FALSE): $AutoInstallIIS_Org" -foregroundcolor "red";
    Write-Host "Exiting...";
    Break;
      }

$AutoInstallMissingIISFeatures_Org=$AutoInstallMissingIISFeatures;
$AutoInstallMissingIISFeatures="$AutoInstallMissingIISFeatures".ToUpper();
IF ($AutoInstallMissingIISFeatures -ne "TRUE" -and $AutoInstallMissingIISFeatures -ne "FALSE"){
    Write-Host "ERROR! The -AutoInstallMissingIISFeatures parameter you passed is an unacceptable value (TRUE/FALSE): $AutoInstallMissingIISFeatures_Org" -foregroundcolor "red";
    Write-Host "Exiting...";
    Break;
      }

$AutoInstallSMTP_Org=$AutoInstallSMTP;
$AutoInstallSMTP="$AutoInstallSMTP".ToUpper();
IF ($AutoInstallSMTP -ne "TRUE" -and $AutoInstallSMTP -ne "FALSE"){
    Write-Host "ERROR! The -AutoInstallSMTP parameter you passed is an unacceptable value (TRUE/FALSE): $AutoInstallSMTP_Org" -foregroundcolor "red";
    Write-Host "Exiting...";
    Break;
      }


$AutoConfigureSMTP_Org=$AutoConfigureSMTP;
$AutoConfigureSMTP="$AutoConfigureSMTP".ToUpper();
IF ($AutoConfigureSMTP -ne "TRUE" -and $AutoConfigureSMTP -ne "FALSE"){
    Write-Host "ERROR! The -AutoConfigureSMTP parameter you passed is an unacceptable value (TRUE/FALSE): $AutoConfigureSMTP_Org" -foregroundcolor "red";
    Write-Host "Exiting...";
    Break;
      }
<#--- PARAMETERS INPUT VALIDATION ENDS HERE. ---#>

<#--- INITIALIZE SCRIPT-WIDE VARIABLES. ---#>
$b_IS_IIS_INSTALLED = 0; #FALSE
$Has_IIS_Been_Installed = $null;
$b_IS_IIS_RUNNING = 0; #FALSE
$Status_Is_IIS_Running = $null;
$b_IS_SMTP_INSTALLED = 0; #FALSE
$Has_SMTP_Been_Installed = $null;
$b_IS_SMTP_RUNNING = 0; #FALSE
$StartMode_SMTP = $null;
$Status_Is_SMTP_Running = $null;
$b_CurrentWindowsFeatureInstalled = 0; #FALSE
$num_IIS_MissingFeaturesCnt = 0;
#--
$BeginReboot=0; #FALSE
#-- IIS Tier1 Features MUST be installed FIRST.
$IISFeaturesInstallListTier1 = "IIS-WebServerRole","IIS-WebServer","IIS-CommonHttpFeatures","IIS-StaticContent","IIS-DefaultDocument",
"IIS-DirectoryBrowsing","IIS-HttpErrors","IIS-HttpRedirect","IIS-ApplicationDevelopment",
"IIS-ISAPIExtensions","IIS-ISAPIFilter","IIS-HealthAndDiagnostics",
"IIS-HttpLogging","IIS-LoggingLibraries","IIS-HttpTracing","IIS-ODBCLogging","IIS-Security",
"IIS-WindowsAuthentication","IIS-ClientCertificateMappingAuthentication","IIS-IISCertificateMappingAuthentication",
"IIS-RequestFiltering","IIS-Performance","IIS-HttpCompressionStatic","IIS-WebServerManagementTools","IIS-ManagementConsole",
"IIS-ManagementScriptingTools","IIS-ManagementService","IIS-IIS6ManagementCompatibility","IIS-Metabase",
"IIS-WMICompatibility","IIS-LegacyScripts","ServerManager-Core-RSAT-Feature-Tools";
#-- IIS Tier2 Features can only be installed AFTER the Tier1 Features have been installed.
$IISFeaturesInstallListTier2 = "IIS-ASP","IIS-ASPNET45","IIS-NetFxExtensibility45","IIS-LegacySnapIn","ServerManager-Core-RSAT-Feature-Tools";
#-- SMTP Features can only be installed AFTER the IIS Feature Sets have been installed.
$SMTPFeaturesInstallList = "Smtpsvc-Service-Update-Name","Smtpsvc-Admin-Update-Name","TelnetClient";

<#--- FUNCTIONS BEGIN HERE. ---#>

function Is_IIS_Installed {
   <# Determine if IIS has been installed. #>
   $IIS_Installed = get-wmiobject -query "select * from win32_Service where name='W3svc'" | % {$_.name};
   IF($IIS_Installed -eq "W3SVC"){
      $IIS_Name = get-itemproperty HKLM:\SOFTWARE\Microsoft\InetStp\  | % {$_.setupstring};
      $IIS_Version = get-itemproperty HKLM:\SOFTWARE\Microsoft\InetStp\  | % {$_.versionstring};
      $IISReturnNameVersion="$IIS_Name-$IIS_Version";
      $script:b_IS_IIS_INSTALLED = 1; #TRUE
      $script:Has_IIS_Been_Installed = $IISReturnNameVersion;}
    ELSE
      {$script:b_IS_IIS_INSTALLED = 0; #FALSE
       $script:Has_IIS_Been_Installed = $null;}
}

function Is_IISAdmin_Running {
   <# Determine if IIS is running. #>
   $IIS_Service = get-wmiobject Win32_Service -Filter "name='IISADMIN'";
   IF($IIS_Service.State -eq "Running"){
     $IIS_State = get-wmiobject -query "select * from win32_Service where name='W3svc'" | % {$_.state};
     $IIS_Name = get-wmiobject -query "select * from win32_Service where name='W3svc'" | % {$_.name};
     $IISReturnNameState="$IIS_Name-$IIS_State";
     $script:b_IS_IIS_RUNNING = 1; #TRUE
     $script:Status_Is_IIS_Running = $IISReturnNameState;}
   ELSE
      {$script:b_IS_IIS_RUNNING = 0; #FALSE
      $script:Status_Is_IIS_Running = $null;}
}

function Is_SMTP_Installed {
   <# Determine if SMTP has been installed. #>
   $SMTP_Installed = get-wmiobject -query "select * from win32_Service where name='smtpsvc'" | % {$_.name};
   IF($SMTP_Installed -eq "SMTPSVC"){
      $SMTP_Name = $SMTP_Installed;
      $script:b_IS_SMTP_INSTALLED = 1; #TRUE
      $script:Has_SMTP_Been_Installed = $SMTP_Installed;}
    ELSE
      {$script:b_IS_SMTP_INSTALLED = 0; #FALSE
       $script:Has_SMTP_Been_Installed = $null;}
}

function Is_SMTP_Running {
   <# Determine if SMTP is running. #>
   $script:StartMode_SMTP = get-wmiobject -query "select * from win32_Service where name='SMTPSVC'" | % {$_.startmode};
   $SMTP_Service = get-wmiobject Win32_Service -Filter "name='SMTPSVC'";
   IF($SMTP_Service.State -eq "Running"){
     $SMTP_State = get-wmiobject -query "select * from win32_Service where name='SMTPSVC'" | % {$_.state};
     $SMTP_Name = get-wmiobject -query "select * from win32_Service where name='SMTPSVC'" | % {$_.name};
     $SMTPReturnNameState="$SMTP_Name-$SMTP_State";
     $script:b_IS_SMTP_RUNNING = 1; #TRUE
     $script:Status_Is_SMTP_Running = $SMTPReturnNameState;}
   ELSE
      {$script:b_IS_SMTP_RUNNING = 0; #FALSE
      $script:Status_Is_SMTP_Running = $null;}
}

function Install_IIS_FeatureSet {
   <# IIS Tier1 Features MUST be installed FIRST. #>
   FOREACH ($newFeature IN $IISFeaturesInstallListTier1)
   {Write-Host "`nAttempting to install the following IIS Tier-1 Feature: $newFeature";
    TRY{Enable-WindowsOptionalFeature -Online -FeatureName $newFeature -All;}
    CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
   }
   <# IIS Tier2 Features can only be installed AFTER the Tier1 Features have been installed. #>
   FOREACH ($newFeature IN $IISFeaturesInstallListTier2)
   {Write-Host "`nAttempting to install the following IIS Tier-2 Feature: $newFeature";
    TRY{Enable-WindowsOptionalFeature -Online -FeatureName $newFeature -All;}
    CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
   }
}


function Install_SMTP_FeatureSet {
   <# Install the SMTP Feature Set. #>
   FOREACH ($newFeature IN $SMTPFeaturesInstallList)
   {Write-Host "`nAttempting to install the following SMTP Feature: $newFeature";
    TRY{Enable-WindowsOptionalFeature -Online -FeatureName $newFeature -All;}
    CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
   }
}


function AutoRebootCountDown($WaitMinutes) {
   # Initialize function varaibles.
   $IterationCount=0;
   $IterationCountMax=10;
   $StartTime = get-date;
   $EndTime   = $StartTime.addMinutes($WaitMinutes);
   $TimeSpan = New-TimeSpan $StartTime $EndTime;
   #---
   $SaveY = [console]::CursorTop;
   $SaveX = [console]::CursorLeft;
   #---
   $ConsoleType = $host.Name;
   
    while ($TimeSpan -gt 0)
	{   $IterationCount++;
        $TimeSpan = New-TimeSpan $(get-date) $EndTime
        # The PowerShell ISE requires special handling when writing the timer output; it doesn't 
        # handle the [console] commands well and produces errors. Therefore, the output will differ
        # from the actual PowerShell console output somewhat.
        IF ($ConsoleType -eq "Windows PowerShell ISE Host"){
           IF ($IterationCount -eq $IterationCountMax) {
              cls;
              Write-Host "REBOOT REQUIRED!!! An automatic reboot is pending." -backgroundcolor black -foregroundcolor red;
              Write-Host "Press CTRL-C is you wish to perform a MANUAL REBOOT at a later time...." -backgroundcolor black -foregroundcolor yellow;
              $IterationCount=0;   
              }
           write-output $([string]::Format("Time Remaining: {0:d2}:{1:d2}:{2:d2}", $TimeSpan.hours, $TimeSpan.minutes, $TimeSpan.seconds));
           }
        ELSE {
          [console]::setcursorposition($SaveX,$SaveY);
          write-host -nonewline $([string]::Format("Time Remaining: {0:d2}:{1:d2}:{2:d2}", $TimeSpan.hours, $TimeSpan.minutes, $TimeSpan.seconds)) -backgroundcolor black -foregroundcolor white;
          }
        
        sleep 1;
    }
    Write-Host '';
    Write-Host 'Reboot Countdown Complete' -foregroundcolor yellow;
    $script:BeginReboot=1; # A successful (uninterrupted) countdown will force a reboot.
}

function ValidateSingleWindowsFeature($WinFeatureName){
   # Initialize function varaibles.
   $b_WinFeatureIsEnabled = 0;
   $WinFeatureStatus = $null;
   TRY{$WinFeatureStatus = Get-WindowsOptionalFeature -Online | where {$_.FeatureName -eq $WinFeatureName} | % {$_.State};}
   CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
   IF ($WinFeatureStatus -eq "Enabled") {
      $b_WinFeatureIsEnabled = 1; #TRUE. This Windows feature is installed and ENABLED.
      return $b_WinFeatureIsEnabled;
      }
   ELSE {
      $b_WinFeatureIsEnabled = 0; #FALSE. This Windows feature is NOT installed (DISABLED).
       # Attempt to AutoInstall the missing feature and any of its dependencies (the -All switch).
      IF ($AutoInstallMissingIISFeatures -eq "TRUE"){
         Write-Host "`nAttempting to auto-install the following missing feature: $WinFeatureName" -foregroundcolor yellow;
         TRY{Enable-WindowsOptionalFeature -Online -FeatureName $WinFeatureName -All;}
         CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
       }
      return $b_WinFeatureIsEnabled;
      }
}

function VerifyInstalledWindowsFeatures ($WindowsFeaturesList) {
   FOREACH ($currentFeature IN $WindowsFeaturesList){
      $script:b_CurrentWindowsFeatureInstalled = ValidateSingleWindowsFeature($currentFeature);
   IF ($b_CurrentWindowsFeatureInstalled) {
      Write-Host "`tWindows Feature [$currentFeature]: Installed/Enabled" -foregroundcolor green;
      }
   ELSE
      {
      $script:num_IIS_MissingFeaturesCnt++; # Increase the count of missing IIS/SMTP features.
      Write-Host "`tWindows Feature [$currentFeature]: NOT Installed/Disabled" -foregroundcolor red;
      }
    }
}


<#--- FUNCTIONS END HERE. ---#>

<#--- MAIN PROCESSING BEGINS HERE. ---#>
## Determine if IIS has been installed.
TRY{Is_IIS_Installed;}
CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
#-----
IF ($b_IS_IIS_INSTALLED){
   Write-Host "IIS has been INSTALLED: $Has_IIS_Been_Installed";
   ## Determine if IIS is currently running.
   TRY{Is_IISAdmin_Running;}
   CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
   IF ($b_IS_IIS_RUNNING){
      Write-Host "IIS is RUNNING: $Status_Is_IIS_Running";}
   ELSE {
      Write-Host "IIS is NOT running...";
      ## Try to restart IIS.
      IF ($AutoRestartIIS -eq "TRUE"){
         Write-Host "Will attempt to RESTART IIS now...";
         TRY{Invoke-Command -ScriptBlock {iisreset /START};}
         CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
      }
   }
   # Validate that all the expected IIS Features are actually installed and Enabled.
   Write-Host "`nValidating that all the expected IIS Features are Installed and Enabled..." -foregroundcolor yellow;
   VerifyInstalledWindowsFeatures($IISFeaturesInstallListTier1);
   VerifyInstalledWindowsFeatures($IISFeaturesInstallListTier2);
   # If any IIS or SMTP features are missing, noitify the user how to automate getting them installed.
   IF ($script:num_IIS_MissingFeaturesCnt -gt 0){
      Write-Host "`nThere appear to be $script:num_IIS_MissingFeaturesCnt missing IIS and/or SMTP features." -foregroundcolor yellow;
      Write-Host "You can have the script try to automatically install/enable these features by" -foregroundcolor yellow;
      Write-Host "rerunning this script using the below parameter option(s):" -foregroundcolor "yellow";
      Write-Host "`t`.\IIS_InstallationScript.ps1 -AutoInstallMissingIISFeatures TRUE" -foregroundcolor green;
      Write-Host "`nOr you can try to install them indivudually using the following syntax:" -foregroundcolor yellow;
      Write-Host "`tEnable-WindowsOptionalFeature -Online -FeatureName {Missing Feature Name}" -foregroundcolor green;
      Write-Host "`tExample:" -foregroundcolor white;
      Write-Host "`tEnable-WindowsOptionalFeature -Online -FeatureName IIS-ODBCLogging" -foregroundcolor white;
   }
}
ELSE {
   Write-Host "WARNING! IIS has NOT been INSTALLED!" -foregroundcolor "red";
   <# If $AutoInstallIIS=TRUE, attempt to install the required IIS Feature Set. #>
   IF ($AutoInstallIIS -eq "TRUE"){
      Install_IIS_FeatureSet;
      }
   ELSE {
      Write-Host "IIS WILL NOT be installed at this time." -foregroundcolor red;
      Write-Host "`nIf you wish to have IIS automatically installed:" -foregroundcolor yellow;
      Write-Host "Rerun this script using the below parameter option(s):" -foregroundcolor yellow;
      Write-Host "`n`.\IIS_InstallationScript.ps1 -AutoInstallIIS TRUE`n" -foregroundcolor green;
      }
}


## Determine if SMTP has been installed.
TRY{Is_SMTP_Installed;}
CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
#-----
IF ($b_IS_SMTP_INSTALLED){
   ## If the SMTP service Startup Mode is AUTOMATIC, and is NOT running,
   ## attempt to restart it.
   TRY{Is_SMTP_Running;}
   CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
   IF(-not $b_IS_SMTP_RUNNING){
       Write-Host "`nSMTP is NOT running...";
       Write-Host "SMTP Startup Type: $StartMode_SMTP...";
       IF ($AutoRestartSMTP -eq "TRUE" -and $StartMode_SMTP -eq "Auto"){
       Write-Host "`nWill attempt to RESTART SMTP now...";
       TRY{Start-Service -InputObject (Get-Service -Name SMTPSVC);}
       CATCH{Write-Error -Exception $PSItem -ErrorAction Stop};
       }
       ELSE {
          Write-Host "`nSMTP service WILL NOT be RESTARTED at this time...";
       }
   }
   ELSE { 
      Write-Host "`nSMTP service is RUNNING: $Status_Is_SMTP_Running";
   }
   # Validate that all the expected SMTP Features are actually installed and Enabled.
   Write-Host "`nValidating that all the expected SMTP Features are Installed and Enabled..." -foregroundcolor yellow;
   VerifyInstalledWindowsFeatures($SMTPFeaturesInstallList);
}
ELSE {
   Write-Host "`nWARNING! SMTP has NOT been INSTALLED!" -foregroundcolor "red";
   <# If $AutoInstallSMTP=TRUE, attempt to install the required SMTP Feature Set. #>
   IF ($AutoInstallSMTP -eq "TRUE"){
      Install_SMTP_FeatureSet;
      ##;
      }
   ELSE {
      Write-Host "SMTP WILL NOT be installed at this time." -foregroundcolor "red";
      Write-Host "`nIf you wish to have SMTP automatically installed:" -foregroundcolor "yellow";
      Write-Host "Rerun this script using the below parameter option(s):" -foregroundcolor "yellow";
      Write-Host "`.\IIS_InstallationScript.ps1 -AutoInstallSMTP TRUE`n" -foregroundcolor "green";
      }

}

## Reboot the server if the $AutoReboot parameter is set to TRUE.
IF ($AutoReboot -eq "TRUE"){
   cls;
   ##AutoRebootCountdown 10; # Ten minute count down.
   AutoRebootCountdown .16; # 10-Second count down (testing purposes).
   IF ($BeginReboot) {
      Write-Host "REBOOTING THE SERVER NOW..."  -backgroundcolor black -foregroundcolor red;
      sleep 5;
      Restart-Computer;
      break;
   }
   ELSE {
      Write-Host "REBOOTING of the SERVER will NOT occur..." -backgroundcolor black;
   }
}


<#--- MAIN PROCESSING ENDS HERE. ---#>

## Work-In-Progress Reference Only! ##
## Invoke-Command -ScriptBlock {iisreset /START}
## Invoke-Command -ScriptBlock {iisreset /STOP}
##
## get-wmiobject -query "select * from win32_Service where name='SMTPSVC'"
## get-wmiobject -query "select * from win32_Service where name='SMTPSVC'" | % {$_.startmode};
## get-wmiobject -query "select * from win32_Service where name='SMTPSVC'" | % {$_.state};
## get-wmiobject -query "select * from win32_Service where name='SMTPSVC'" | % {$_.name};
## Stop-Service -InputObject (Get-Service -Name SMTPSVC)
## Start-Service -InputObject (Get-Service -Name SMTPSVC)
##
## Import-Module Webadministration <-- this one probably not needed for IIS 8.0+
## Get-ChildItem -Path IIS:\Sites
##
## Name             ID   State      Physical Path                  Bindings                                  
## ----             --   -----      -------------                  --------                                  
## SimCorp          1    Started    D:\apps\simcorp                http *:80: 
##
## Get-ChildItem -Path IIS:\AppPools
## Name                     State        Applications                                
## ----                     -----        ------------                                
## .NET v4.5                Started                                                  
## .NET v4.5 Classic        Started                                                  
## DefaultAppPool           Started                                                  
## SimCorp                  Started      SimCorp
##
##
## We can then check all of the properties on that app pool using Get-ItemProperty.
## Get-ItemProperty IIS:\AppPools\".NET v4.5 Classic"|select *
##
## Retrieve a single App Pool property.
## Get-ItemProperty IIS:\AppPools\".NET v4.5 Classic"|select * | % {$_.queueLength}
##
## Stop-WebAppPool SimCorp
## Get-WebAppPoolState SimCorp
## Start-WebAppPool SimCorp
## 
##
## You probably forgot to run "Add-PSSnapin WebAdministration" before executing other IIS cmdlets.
##
## Display the IIS managed modules.
## Get-WebManagedModule
##
## Check for Installed Features:
## Get-WindowsOptionalFeature -Online | where {$_.state -eq "Enabled"} | ft -Property featurename
##
## Check for Features available but Not Installed
## Get-WindowsOptionalFeature -Online | where {$_.state -eq "Disabled"} | ft -Property featurename
##
## Disable a Windows Feature
## Disable-WindowsOptionalFeature -Online -FeatureName IIS-DirectoryBrowsing
##
## Get-NetIPAddress -AddressFamily IPv4
## Get-NetIPAddress -AddressFamily IPv4 | Sort-Object -Property IPAddress | Format-Table
## Get-NetIPAddress -AddressFamily IPv4 | % {$_.IPAddress}
##
## get-wmiobject -namespace root\MicrosoftIISv2 -Query "Select * from IIsSmtpServerSetting"
##
## Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName localhost | % {$_.IPAddress}
##
## Get-WmiObject Win32_NetworkAdapterConfiguration| ? {$_.IPEnabled}
##
##
##
## $smtpserversetting = get-wmiobject -namespace root\MicrosoftIISv2 -Query "Select * from IIsSmtpServerSetting"
## $smtpserversetting.RelayForAuth=0
## $smtpserversetting.SmartHost="mxtest.wellsfargo.com"
## $smtpserversetting.Put()
##
##
## Get-WmiObject -namespace root/MicrosoftIISV2 -class IISWebVirtualDirSetting
##
## # Search Windows Features query output for Enabled or Disabled features - exmples.
## Get-WindowsOptionalFeature -Online | where {$_.state -eq "Enabled"} | Out-String -Stream | Select-String "smb"
## Get-WindowsOptionalFeature -Online | where {$_.state -eq "Disabled"} | Out-String -Stream | Select-String "smb"
## Get-WindowsOptionalFeature -Online | where {$_.state -eq "Disabled"} | ft -Property featurename | Out-String -Stream | Select-String "smb"


