exit
#Save powershell to taskbar
systeminfo.exe

Set-ExecutionPolicy Unrestricted -Force
Set-ExecutionPolicy bypass -Force

#Install Telnet
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

