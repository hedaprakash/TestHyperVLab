exit

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
Set-VM -Name $VMName -AutomaticStartAction Nothing
Set-VM -Name $VMName -AutomaticStopAction turnoff


Start-VM  "$($VMName)"
vmconnect localhost $($VMName)



$vmname="vW19Router"
[string] $Adminaccount=".\administrator"
[string] $AdminPassword="tttttt1!"
$secretAdminpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Adminaccount, $secretAdminpassword
get-pssession| remove-pssession 
Enter-PSSession -vmName $vmname -Credential $credential #-Authentication Credssp

Get-NetAdapter
$NewSwitchName="LanNet"
$Networkinterface=Get-NetAdapter | ? status -eq ‘up’ | Select-Object -ExpandProperty ifIndex
$CurrentSwitchName=Get-NetAdapter | ? status -eq ‘up’ | Select-Object -ExpandProperty name
"`n`nNetworkinterface= $Networkinterface , CurrentSwitchName: $CurrentSwitchName , NewSwitchName= $NewSwitchName "

Get-NetIPAddress -InterfaceIndex $Networkinterface

Rename-NetAdapter -Name $CurrentSwitchName -NewName $NewSwitchName

Disable-NetAdapterBinding -Name $NewSwitchName –ComponentID ms_tcpip6

Restart-NetAdapter -Name $NewSwitchName

Get-NetIPAddress -InterfaceIndex $Networkinterface

Get-NetAdapter

hostname

Stop-Computer -force  


exit


$NewSwitchName="Lan10"
Add-VMNetworkAdapter -VMName "vW19Router" -SwitchName $NewSwitchName
Start-VM  $VMName

Enter-PSSession -vmName $vmname -Credential $credential 

$NewSwitchName="Lan10"
Get-NetAdapter|Where-Object {$_.name  -notMatch "lan"}| Sort-Object -Property Virtual,InterfaceDescription
$Networkinterface=Get-NetAdapter  | Where-Object {$_.name  -notMatch "lan"} | Select-Object -ExpandProperty ifIndex
$CurrentSwitchName=Get-NetAdapter  | Where-Object {$_.name  -notMatch "lan"} | Select-Object -ExpandProperty name
$DefaultGateway = "10.10.10.1"
$DnsAddress="10.10.10.2" # DC will be configured next
"`n`nNetworkinterface= $Networkinterface , CurrentSwitchName: $CurrentSwitchName , NewSwitchName= $NewSwitchName "

Get-NetIPAddress -InterfaceIndex $Networkinterface

Rename-NetAdapter -Name $CurrentSwitchName -NewName $NewSwitchName

Disable-NetAdapterBinding -Name $NewSwitchName –ComponentID ms_tcpip6

Get-NetIPAddress -InterfaceIndex $Networkinterface

New-NetIPAddress -InterfaceIndex $Networkinterface -IPAddress 10.10.10.1 -PrefixLength 24  

Restart-NetAdapter -Name $NewSwitchName

Get-NetIPAddress -InterfaceIndex $Networkinterface

Get-NetAdapter

Stop-Computer  -force  

exit

$NewSwitchName="Lan20"
Add-VMNetworkAdapter -VMName "vW19Router" -SwitchName $NewSwitchName
get-vm -Name $VMName | Get-VMNetworkAdapter 
Start-VM  $VMName

Enter-PSSession -vmName $vmname -Credential $credential

Get-NetAdapter|Where-Object {$_.name  -notMatch "lan"}| Sort-Object -Property Virtual,InterfaceDescription
$NewSwitchName="Lan20"
$Networkinterface=Get-NetAdapter  | Where-Object {$_.name  -notMatch "lan"} | Select-Object -ExpandProperty ifIndex
$CurrentSwitchName=Get-NetAdapter  | Where-Object {$_.name  -notMatch "lan"} | Select-Object -ExpandProperty name
"`n`nNetworkinterface= $Networkinterface , CurrentSwitchName: $CurrentSwitchName , NewSwitchName= $NewSwitchName "


Get-NetIPAddress -InterfaceIndex $Networkinterface

Rename-NetAdapter -Name $CurrentSwitchName -NewName $NewSwitchName

Disable-NetAdapterBinding -Name $NewSwitchName –ComponentID ms_tcpip6

Get-NetIPAddress -InterfaceIndex $Networkinterface

New-NetIPAddress -InterfaceIndex $Networkinterface -IPAddress 20.20.20.1 -PrefixLength 24  

Restart-NetAdapter -Name $NewSwitchName

Get-NetIPAddress -InterfaceIndex $Networkinterface

Get-NetAdapter | ? status -eq ‘up’ | Get-NetIPAddress -AddressFamily IPv4 | ft InterfaceAlias,IPAddress

# all IPs are set by now
hostname
ping google.com
ping 10.10.10.1
ping 10.10.10.3
ping 20.20.20.1
ping 20.20.20.3

Install-WindowsFeature -Name Routing -IncludeManagementTools

#Manually configure NAT and lan routing

Restart-Computer 


# completed







