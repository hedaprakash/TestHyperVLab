$unattenndedbase=@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
      <settings pass="specialize">
            <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                  <ComputerName>VMNamexxx</ComputerName>
                  <RegisteredOrganization></RegisteredOrganization>
                  <RegisteredOwner></RegisteredOwner>
            </component>
      </settings>
      <settings pass="oobeSystem">
            <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                  <UserAccounts>
                        <AdministratorPassword>
                              <Value>AdministratorPasswordxxx</Value>
                              <PlainText>true</PlainText>
                        </AdministratorPassword>
                  </UserAccounts>
                  <OOBE>
                        <HideEULAPage>true</HideEULAPage>
                        <SkipMachineOOBE>true</SkipMachineOOBE>
                  </OOBE>
            </component>
      </settings>
</unattend>
"@

# Mount DVD drive as F drive

$VMName ="vW19Parent"
$AdministratorPassword="tttttt1!"
$OSvhdx="C:\VHD\$($VMName).vhdx"

mkdir C:\VHD

#stop-vm $VMName -Force
#remove-vm $VMName -Force
#Remove-Item $OSvhdx

$MountResult=New-VHD -Path $OSvhdx -Dynamic -SizeBytes 250GB | Mount-VHD -Passthru |Initialize-Disk  -PartitionStyle MBR -Passthru |New-Partition -AssignDriveLetter -UseMaximumSize |Format-Volume -FileSystem NTFS -Confirm:$false -Force

$MountResult.DriveLetter


$unattennded = $unattenndedbase -replace "VMNamexxx",$VMName -replace "AdministratorPasswordxxx",$AdministratorPassword
$unattennded | Out-File "$($MountResult.DriveLetter)`:\unattend.xml" -Encoding ASCII

Dismount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue


New-VM -Name "$($VMName)" -SwitchName lanNet -VHDPath "C:\VHD\$($VMName).vhdx"
Set-VMProcessor -VMName "$($VMName)" -Count 4
Set-VMMemory -VMName "$($VMName)" -DynamicMemoryEnabled $true -MinimumBytes 512MB -MaximumBytes 9048MB -Buffer 20  -StartupBytes 8048MB
Enable-VMIntegrationService -Name "Guest Service Interface" -VMName $($VMName)
Set-VM -Name $VMName -AutomaticStartAction Nothing
Set-VM -Name $VMName -AutomaticStopAction turnoff
Set-VM -VMName "$($VMName)" -AutomaticCheckpointsEnabled $False
Set-VMDvdDrive -VMName $VMName -Path "D:\SQLSetup_ALL\SQLBinaries\windows server 2019_June20\en_windows_server_2019_updated_june_2020_x64_dvd_7757177c.iso"


Start-VM  "$($VMName)"
vmconnect localhost $($VMName)

# configure Parent VM

$vmname="vW19Parent"
get-vm -Name $vmname | Get-VMNetworkAdapter 
[string] $Adminaccount=".\administrator"
[string] $AdminPassword="tttttt1!"
$secretAdminpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Adminaccount, $secretAdminpassword
get-pssession| remove-pssession 
#$session = New-PSSession -cn $vmname -Credential $credential #-Authentication Credssp
Enter-PSSession -vmName $vmname -Credential $credential #-Authentication Credssp

#Disable firewall 
netsh advfirewall set allprofiles state off

# enable RDP to VM
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "SecurityLayer" -Value "1"  -Force
(Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1,1) | Out-Null(Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null#Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true

# install telnet 
Add-WindowsFeature -Name Telnet-Client



#Start winrm service 
#    Set-Service -Name WinRM -StartupType Automatic
#    Get-Service -Name WinRM | start-Service

    Get-Service -Name WinRM 


#Disable-UAC
$SystemKey = “HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System”
$UACAleadySet=Get-ItemProperty -Path $SystemKey -Name "EnableLUA"  -ErrorAction Continue
$UACAleadySet = $UACAleadySet.EnableLUA
Set-ItemProperty -Path $SystemKey -Name "EnableLUA" -Value 0  -Force

Get-NetAdapter
$Networkinterface=Get-NetAdapter  | Where-Object {$_.name  -notMatch "lan"} | Select-Object -ExpandProperty ifIndex

Get-NetIPAddress -InterfaceIndex $Networkinterface

# No Need to Update 

#update all patches, reboot 
$vmname="vW19Parent"
get-vm -Name $vmname | Get-VMNetworkAdapter 
[string] $Adminaccount=".\administrator"
[string] $AdminPassword="tttttt1!"
$secretAdminpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Adminaccount, $secretAdminpassword
get-pssession| remove-pssession 
#$session = New-PSSession -cn $vmname -Credential $credential #-Authentication Credssp
Enter-PSSession -vmName $vmname -Credential $credential #-Authentication Credssp

# Parent VM disable updates
        $AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings
        $AUSettings.NotificationLevel = 1
        $AUSettings.Save
        sc.exe config wuauserv start=disabled



"Enabling delegation access"
Get-WSManCredSSP
Enable-WSManCredSSP -Role Server -Force | out-null
Start-Sleep -s 2 
Get-WSManCredSSP
Get-Item -Path WSMan:\localhost\Client\TrustedHosts # make sure value is *
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value * -Concatenate -Force
Get-Item -Path WSMan:\localhost\Client\TrustedHosts # make sure value is *

#(Get-WSManCredSSP) -match "PHRyzen"


Test-WSMan 
#winrm e winrm/config/listener
#Get-Service -Name WinRM | Restart-Service

remove-item "C:\unattend.xml"

ping google.com

Restart-Computer -Force


# run it on vW19Parent server directly
# c:\windows\system32\sysprep\Sysprep /generalize /shutdown /oobe

remove-vm -Name vW19Parent -Force

#Make parent disk as read only 
