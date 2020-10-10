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

# get-vm -Name vW19AD | Get-VMNetworkAdapter 


exit

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
Set-VM -Name $VMName -AutomaticStartAction Start
Set-VM -Name $VMName -AutomaticStopAction turnoff


Start-VM  "$($VMName)"
vmconnect localhost $($VMName)


$vmname="vW19AD"
[string] $Adminaccount=".\administrator"
[string] $AdminPassword="tttttt1!"
$secretAdminpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Adminaccount, $secretAdminpassword
get-pssession| remove-pssession 
#$session = New-PSSession -cn $vmname -Credential $credential #-Authentication Credssp
Enter-PSSession -vmName $vmname -Credential $credential #-Authentication Credssp

Get-NetAdapter
$NewSwitchName="Lan10"
$Networkinterface=Get-NetAdapter  | Where-Object {$_.name  -notMatch "lan"} | Select-Object -ExpandProperty ifIndex
$CurrentSwitchName=Get-NetAdapter  | Where-Object {$_.name  -notMatch "lan"} | Select-Object -ExpandProperty name
$DefaultGateway = "10.10.10.1"
$DnsAddress="10.10.10.2"
"`n`nNetworkinterface= $Networkinterface , CurrentSwitchName: $CurrentSwitchName , NewSwitchName= $NewSwitchName "

Get-NetIPAddress -InterfaceIndex $Networkinterface

Rename-NetAdapter -Name $CurrentSwitchName -NewName $NewSwitchName

Disable-NetAdapterBinding -Name $NewSwitchName –ComponentID ms_tcpip6

Get-NetIPAddress -InterfaceIndex $Networkinterface

New-NetIPAddress -InterfaceIndex $Networkinterface -IPAddress 10.10.10.2 -PrefixLength 24  -DefaultGateway $DefaultGateway
Set-DnsClientServerAddress -InterfaceAlias $NewSwitchName -ServerAddresses 8.8.8.8

Get-NetIPAddress -InterfaceIndex $Networkinterface

Restart-NetAdapter -Name $NewSwitchName


Get-NetAdapter



hostname
ping google.com
ping 10.10.10.1
ping 20.20.20.1
ping 20.20.20.3


# Check iif domain exists
nltest /dsgetdc:sqlfeatures.local /force

# step 1
Add-WindowsFeature -Name "ad-domain-services" -IncludeAllSubFeature -IncludeManagementTools 
Add-WindowsFeature -Name "dns" -IncludeAllSubFeature -IncludeManagementTools 
Add-WindowsFeature -Name "gpmc" -IncludeAllSubFeature -IncludeManagementTools 

# step 2

$domainname = "sqlfeatures.local" 
$netbiosName = "sqlfeatures" 
Import-Module ADDSDeployment 

Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode "Win2012" -DomainName $domainname -DomainNetbiosName $netbiosName -ForestMode "Win2012" -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true –SafeModeAdministratorPassword (ConvertTo-SecureString ‘tttttt1!’ –AsPlainText –Force)
#############################wait here####################
# system will restart after that

Start-Sleep -s 600

exit

vmconnect localhost $($VMName)
# step 3
Enter-PSSession -vmName $vmname -Credential $credential

New-ADOrganizationalUnit -Name DomainAdmins -Path "DC=sqlfeatures,DC=local"
New-ADOrganizationalUnit -Name SqlServiceAccounts -Path "DC=sqlfeatures,DC=local"
New-ADOrganizationalUnit -Name dbhosts -Path "DC=sqlfeatures,DC=local"

$Class = "User"
$dc = "dc=sqlfeatures,dc=local"
$strUser="hvadmin"
$UserPrincipalName = $strUser + "@sqlfeatures.local"
$strUserPassword="tttttt1!"
$ou = "DomainAdmins"
New-ADUser -SamAccountName $strUser -AccountPassword (ConvertTo-SecureString $strUserPassword -AsPlainText -Force) -name $strUser -enabled $true -PasswordNeverExpires $true -Path "OU=$ou,DC=sqlfeatures,DC=local"

Add-ADGroupMember –Identity “Domain Admins” –Members  $strUser

New-ADGroup -Name "SQL DBA support" -SamAccountName SQLDBA -GroupCategory Security -GroupScope Global -DisplayName "SQL Administrators" -Path "OU=SqlServiceAccounts,DC=sqlfeatures,DC=local" -Description "Members of this group are SQL Administrators"  

# creating reverse lookup and domain server reverse lookup
Add-DnsServerPrimaryZone -DynamicUpdate Secure -NetworkId ‘10.10.10.0/24’ -ReplicationScope Domain
Add-DNSServerResourceRecordPTR -ZoneName 10.10.10.in-addr.arpa -Name 59 -PTRDomainName vW19AD.sqlfeatures.local
Add-DNSServerResourceRecordPTR -ZoneName 10.10.10.in-addr.arpa -Name 59 -PTRDomainName sqlfeatures.local

Get-NetIPAddress -AddressFamily IPv4 | ft InterfaceAlias,IPAddress

ping google.com
ping 10.10.10.1
ping 20.20.20.1
ping 20.20.20.3
ping sqlfeatures.local


Restart-Computer -force 

exit

