﻿exit
$vmname="vW19db1"
get-vm -Name $vmname | Get-VMNetworkAdapter 
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
$VMIp="10.10.10.11"
"`n`nNetworkinterface= $Networkinterface , CurrentSwitchName: $CurrentSwitchName , NewSwitchName= $NewSwitchName "


Get-NetIPAddress -InterfaceIndex $Networkinterface

Rename-NetAdapter -Name $CurrentSwitchName -NewName $NewSwitchName

Disable-NetAdapterBinding -Name $NewSwitchName –ComponentID ms_tcpip6

Get-NetIPAddress -InterfaceIndex $Networkinterface

New-NetIPAddress -InterfaceIndex $Networkinterface -IPAddress $VMIp -PrefixLength 24  -DefaultGateway $DefaultGateway
Set-DnsClientServerAddress -InterfaceAlias $NewSwitchName -ServerAddresses $DnsAddress

Get-NetIPAddress -InterfaceIndex $Networkinterface

Get-NetAdapter

hostname

ping google.com
ping sqlfeatures.local
ping vW19AD.sqlfeatures.local
ping 10.10.10.1
ping 20.20.20.1


nltest /dsgetdc:sqlfeatures.local /force



(Get-WmiObject Win32_ComputerSystem).UnjoinDomainOrWorkgroup($null,$null,0)
[string] $Adminaccount="sqlfeatures\hvadmin"
[string] $AdminPassword="tttttt1!"
$secretAdminpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Adminaccount, $secretAdminpassword
Add-Computer -DomainName sqlfeatures.local -Credential $credential 
Restart-Computer 

$vmname="vW19db1"
[string] $Adminaccount="sqlfeatures\hvadmin"
[string] $AdminPassword="tttttt1!"
$secretAdminpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Adminaccount, $secretAdminpassword
Enter-PSSession -vmName $vmname -Credential $credential 

Get-WmiObject Win32_ComputerSystem
whoami

Add-WindowsFeature -Name Failover-Clustering –IncludeManagementTools

start-sleep -s 30

Restart-Computer -Force

# Creatre quorum share \\VW19AD\ClusterQuorumFileShare and grant everyone full access

