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







#https://docs.microsoft.com/en-us/windows/deployment/windows-10-poc

exit
Save powershell to taskbar
systeminfo.exe

Set-ExecutionPolicy Unrestricted -Force
Set-ExecutionPolicy bypass -Force

# install RDP visionapp

Add-WindowsFeature -Name Telnet-Client
#win10
Enable-WindowsOptionalFeature –Online –FeatureName  TelnetClient 

"Enable RDP"  
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "SecurityLayer" -Value "1"  -Force
(Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1,1) | Out-Null
(Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null
Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true


#Disable-IEESC
$AdminKey = “HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}”
$UserKey = “HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}”
Set-ItemProperty -Path $AdminKey -Name “IsInstalled” -Value 0
Set-ItemProperty -Path $UserKey -Name “IsInstalled” -Value 0



#Enable-PSRemoting -Force

Get-Service -Name WinRM 
Set-Service -Name WinRM -StartupType Automatic
Get-Service -Name WinRM | start-Service
Get-Service -Name WinRM 

Get-Item -Path WSMan:\localhost\Client\TrustedHosts 
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value * -Concatenate -Force
Get-Item -Path WSMan:\localhost\Client\TrustedHosts 

"Disable firewall" 
#netsh advfirewall set allprofiles state off

#Disable-UAC
$SystemKey = “HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System”
$UACAleadySet=Get-ItemProperty -Path $SystemKey -Name "EnableLUA"  -ErrorAction Continue
$UACAleadySet = $UACAleadySet.EnableLUA
Set-ItemProperty -Path $SystemKey -Name "EnableLUA" -Value 0  -Force
Stop-Process -Name Explorer -Force
Start-Process Explorer


Rename-Computer w10demo

systeminfo
#Run on windows 10
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V –All
# system will restart now

#after reboot
Set-VMhost -EnableEnhancedSessionMode $TRUE

Get-NetAdapter
Get-NetAdapter |?{$_.Status -eq "Up"}


New-VMSwitch -Name lan10 -SwitchType Internal -Notes "lan10 network"
New-VMSwitch -Name lan20 -SwitchType Internal -Notes "lan20 network"
New-VMSwitch -Name lanNet -NetAdapterName (Get-NetAdapter |?{$_.Status -eq "Up" -and !$_.Virtual}).Name -Notes "lanNet"

Get-NetAdapter |?{$_.Status -eq "Up"}| Sort-Object -Property Virtual,InterfaceDescription

Rename-NetAdapter -Name "vEthernet (lan10)" -NewName Lan10
Rename-NetAdapter -Name "vEthernet (lan20)" -NewName lan20
Rename-NetAdapter -Name "vEthernet (lanNet)" -NewName lanNet

Get-NetAdapter |?{$_.Status -eq "Up"}| Sort-Object -Property Virtual,InterfaceDescription| select name,ifindex

#disable IPV6
Disable-NetAdapterBinding -Name "*lan*" –ComponentID ms_tcpip6

#Setup Lan10 with right IP
Get-NetIPAddress -InterfaceIndex 73
New-NetIPAddress -InterfaceIndex 73 -IPAddress 10.10.10.3 -PrefixLength 24

#Setup Lan20 with right IP
Get-NetAdapter |?{$_.Status -eq "Up"}| Sort-Object -Property Virtual,InterfaceDescription | select name,ifindex
Get-NetIPAddress -InterfaceIndex 69
New-NetIPAddress -InterfaceIndex 69 -IPAddress 20.20.20.3 -PrefixLength 24
Get-NetIPAddress -InterfaceIndex 69

# lanNet
Get-NetIPAddress -InterfaceIndex 81

Restart-Computer 

# create parent 2019 VM



$VMName ="vW19Router"
$AdministratorPassword="tttttt1!"
$OSvhdx="C:\VHD\$($VMName).vhdx"

New-VHD  -Path $OSvhdx -ParentPath "C:\VHD\vW19Parent.vhdx"  -SizeBytes 250GB   | Out-Null
$Drive = (Mount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue -PassThru | Get-Disk | Get-Partition).DriveLetter
$Drive =$Drive | select -last 1

$unattennded = $unattenndedbase -replace "VMNamexxx",$VMName -replace "AdministratorPasswordxxx",$AdministratorPassword
$unattennded | Out-File "$Drive`:\unattend.xml"  -Encoding ASCII

Dismount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue


New-VM -Name "$($VMName)" -SwitchName lanNet -VHDPath "C:\VHD\$($VMName).vhdx"
Set-VMProcessor -VMName "$($VMName)" -Count 1
Set-VMMemory -VMName "$($VMName)" -DynamicMemoryEnabled $true -MinimumBytes 512MB -MaximumBytes 4096MB -Buffer 30  -StartupBytes 1024MB
Enable-VMIntegrationService -Name "Guest Service Interface" -VMName $($VMName)
Set-VM -VMName "$($VMName)" -AutomaticCheckpointsEnabled $False


Start-VM  "$($VMName)"
vmconnect localhost $($VMName)


# configure AD/DNS server

$VMName ="vW19AD"
$AdministratorPassword="tttttt1!"
$OSvhdx="C:\VHD\$($VMName).vhdx"

#stop-vm $VMName -Force
#remove-vm $VMName -Force
#Remove-Item $OSvhdx

New-VHD  -Path $OSvhdx -ParentPath "C:\VHD\vW19Parent.vhdx"  -SizeBytes 250GB   | Out-Null
$Drive = (Mount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue -PassThru | Get-Disk | Get-Partition).DriveLetter
$Drive =$Drive | select -last 1

$unattennded = $unattenndedbase -replace "VMNamexxx",$VMName -replace "AdministratorPasswordxxx",$AdministratorPassword
$unattennded | Out-File "$Drive`:\unattend.xml"  -Encoding ASCII

Dismount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue


New-VM -Name "$($VMName)" -SwitchName lan10 -VHDPath "C:\VHD\$($VMName).vhdx"
Set-VMProcessor -VMName "$($VMName)" -Count 1
Set-VMMemory -VMName "$($VMName)" -DynamicMemoryEnabled $true -MinimumBytes 512MB -MaximumBytes 4096MB -Buffer 30
Enable-VMIntegrationService -Name "Guest Service Interface" -VMName $($VMName)
Set-VM -VMName "$($VMName)" -AutomaticCheckpointsEnabled $False


Start-VM  "$($VMName)"
vmconnect localhost $($VMName)




$VMName ="vW19db1"
$AdministratorPassword="tttttt1!"
if ($VMName -eq "vW19db3")
{$NewSwitchName="Lan20"} else {$NewSwitchName="Lan10"}


$OSvhdx="C:\VHD\$($VMName).vhdx"
New-VHD  -Path $OSvhdx -ParentPath "C:\VHD\vW19Parent.vhdx"  -SizeBytes 250GB   | Out-Null
$Drive = (Mount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue -PassThru | Get-Disk | Get-Partition).DriveLetter
$Drive =$Drive | select -last 1

$unattennded = $unattenndedbase -replace "VMNamexxx",$VMName -replace "AdministratorPasswordxxx",$AdministratorPassword
$unattennded | Out-File "$Drive`:\unattend.xml"  -Encoding ASCII

Dismount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue


New-VM -Name "$($VMName)" -SwitchName $NewSwitchName -VHDPath "C:\VHD\$($VMName).vhdx"
Set-VMProcessor -VMName "$($VMName)" -Count 1
Set-VMMemory -VMName "$($VMName)" -DynamicMemoryEnabled $true -MinimumBytes 512MB -MaximumBytes 4096MB -Buffer 20  -StartupBytes 2048MB
Enable-VMIntegrationService -Name "Guest Service Interface" -VMName $($VMName)
Set-VM -VMName "$($VMName)" -AutomaticCheckpointsEnabled $False
Set-VMDvdDrive -VMName $VMName -Path "D:\SQLSetup.iso"

Start-VM  "$($VMName)"

vmconnect localhost $($VMName)


$VMName ="vW19app"
$AdministratorPassword="tttttt1!"
$NewSwitchName="Lan10"
$OSvhdx="C:\VHD\$($VMName).vhdx"

#stop-vm $VMName -Force
#remove-vm $VMName -Force
#Remove-Item $OSvhdx

New-VHD  -Path $OSvhdx -ParentPath "C:\VHD\vW19Parent.vhdx"  -SizeBytes 250GB   | Out-Null
$Drive = (Mount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue -PassThru | Get-Disk | Get-Partition).DriveLetter
$Drive =$Drive | select -last 1

$unattennded = $unattenndedbase -replace "VMNamexxx",$VMName -replace "AdministratorPasswordxxx",$AdministratorPassword
$unattennded | Out-File "$Drive`:\unattend.xml"  -Encoding ASCII

Dismount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue


New-VM -Name "$($VMName)" -SwitchName $NewSwitchName -VHDPath "C:\VHD\$($VMName).vhdx"
Set-VMProcessor -VMName "$($VMName)" -Count 2
Set-VMMemory -VMName "$($VMName)" -DynamicMemoryEnabled $true -MinimumBytes 512MB -MaximumBytes 4096MB -Buffer 20  -StartupBytes 2048MB
Enable-VMIntegrationService -Name "Guest Service Interface" -VMName $($VMName)
Set-VM -VMName "$($VMName)" -AutomaticCheckpointsEnabled $False
Set-VMDvdDrive -VMName $VMName -Path "D:\SQLSetup.iso"

Start-VM  "$($VMName)"

vmconnect localhost $($VMName)

# completed
