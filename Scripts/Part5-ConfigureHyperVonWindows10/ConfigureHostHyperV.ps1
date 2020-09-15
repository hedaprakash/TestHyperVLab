exit
# Backup VHD before continuing with next steps

#Save powershell to taskbar

# Change Power options

Rename-Computer w10demo

Restart-Computer 

systeminfo.exe

Set-ExecutionPolicy Unrestricted -Force
Set-ExecutionPolicy bypass -Force

# install RDP visionapp

#win10
Enable-WindowsOptionalFeature –Online –FeatureName  TelnetClient 

Get-Service -Name WinRM 
Set-Service -Name WinRM -StartupType Automatic
Get-Service -Name WinRM | start-Service
Get-Service -Name WinRM 

Get-Item -Path WSMan:\localhost\Client\TrustedHosts 
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value * -Concatenate -Force
Get-Item -Path WSMan:\localhost\Client\TrustedHosts 

"Disable firewall" 
netsh advfirewall set allprofiles state off

#Disable-UAC
$SystemKey = “HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System”
$UACAleadySet=Get-ItemProperty -Path $SystemKey -Name "EnableLUA"  -ErrorAction Continue
$UACAleadySet = $UACAleadySet.EnableLUA
Set-ItemProperty -Path $SystemKey -Name "EnableLUA" -Value 0  -Force
Stop-Process -Name Explorer -Force
Start-Process Explorer

Restart-Computer 

#Run on windows 10
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V –All
# system will restart now

Restart-Computer 

#after reboot
Set-VMhost -EnableEnhancedSessionMode $TRUE

Get-NetAdapter
Get-NetAdapter |?{$_.Status -eq "Up"}

Restart-Computer 


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
Get-NetIPAddress -InterfaceIndex 69
New-NetIPAddress -InterfaceIndex 69 -IPAddress 10.10.10.3 -PrefixLength 24

#Setup Lan20 with right IP
Get-NetAdapter |?{$_.Status -eq "Up"}| Sort-Object -Property Virtual,InterfaceDescription | select name,ifindex
Get-NetIPAddress -InterfaceIndex 75
New-NetIPAddress -InterfaceIndex 75 -IPAddress 20.20.20.3 -PrefixLength 24
Get-NetIPAddress -InterfaceIndex 75

# lanNet
Get-NetIPAddress -InterfaceIndex 62

Restart-Computer 

