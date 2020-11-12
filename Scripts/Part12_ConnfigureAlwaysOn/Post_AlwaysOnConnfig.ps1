
"Setting cluster parameters to avoid duplicate IP's" | Write-Host

$GetClusterResources=get-clusterresource | where-object {$_.ResourceType -like "Network Name"}  | where-object {$_.name -Notlike "Cluster Name"}
$GetClusterResources.name
Get-ClusterResource $GetClusterResources.name | get-ClusterParameter

Get-ClusterResource $GetClusterResources.name | Set-ClusterParameter RegisterAllProvidersIP 0
Get-ClusterResource $GetClusterResources.name | Set-ClusterParameter  HostRecordTTL 60
Get-ClusterResource $GetClusterResources.name  | Update-ClusterNetworkNameResource

get-clusterresource | where-object {$_.ResourceType -like "Network Name"}  | where-object {$_.name -Notlike "Cluster Name"}| get-ClusterParameter


"Updating lease timeout "| Write-Host
$GetClusterAVGResources=get-clusterresource | where-object {$_.ResourceType -like "SQL Server Availability Group"}  
"Get LeaseTimeout before making change"
Get-ClusterResource $GetClusterAVGResources.name | Get-ClusterParameter LeaseTimeout  
Get-ClusterResource $GetClusterAVGResources.name | Set-ClusterParameter LeaseTimeout 30000
Get-ClusterResource $GetClusterAVGResources.name | Get-ClusterParameter LeaseTimeout  

"Updating Subnet delays for multisubnet clusters"| Write-Host
get-cluster | fl *subnet* 
(get-cluster).SameSubnetDelay = 1000
(get-cluster).SameSubnetThreshold = 30
(get-cluster).CrossSubnetDelay = 2000
(get-cluster).CrossSubnetThreshold = 100

get-cluster | fl *subnet* 

foreach ($GetClusterResource in $GetClusterResources)
{
	$ResourceName=$GetClusterResource.name
	$ResourceName | Write-Host
    Stop-ClusterResource $ResourceName
    Start-ClusterResource $ResourceName
}






# Set preferred nodes to node 1 & 2
 
#powershell  -file D:\SQLSetup\scripts\InstallSQL\CreateClusterV2.ps1  -ClusterNodes $ClusterNodes -ClusterIPs $ClusterIPs -ClusterName $ClusterName  -ClusterQuorumFileShare $ClusterQuorumFileShare
# restart all 3 nodes
$ClusterNodesArray= @("vW19db1","vW19db2","vW19db3")
$tempsession = new-pssession -computername $ClusterNodesArray  -Credential $credential 
invoke-command -session $tempsession -scriptblock {Restart-Computer }

Enter-PSSession -vmName $vmname -Credential $credential #-Authentication Credssp


powershell D:\SQLSetup\scripts\InstallSQL\EnableAlwaysON.ps1 -PreConfigbackupFolder "C:\PreAlwaysOnConfigBackups" -AlwaysOnShareFolder "C:\AlwaysOnShare"

powershell -file D:\SQLSetup\scripts\InstallSQL\ConfigureAlwaysONV2.ps1 -AlwaysOnNodes $ClusterNodes -AlwaysOnNodesIPs $alwaysOnServerIPs -SubnetMasks $SubnetMask -avgGroupName $avgGroupName -LsnName $LsnName

powershell -file D:\SQLSetup\Scripts\InstallSQL\VerifyAlwaysON.ps1 -SvcPassword "tttttt1!" -SAPassword  "Sequoia2012#!"


--- YOU MUST EXECUTE THE FOLLOWING SCRIPT IN SQLCMD MODE.
:Connect VW19DB1
ALTER AVAILABILITY GROUP [aW19db] FAILOVER
:Connect VW19DB2
Connect VW19DB2
ALTER AVAILABILITY GROUP [aW19db] FAILOVER

:Connect VW19DB3
ALTER AVAILABILITY GROUP [aW19db] FORCE_FAILOVER_ALLOW_DATA_LOSS;


SELECT a.name as avggroup,b.primary_replica
,(select replica_server_name from sys.availability_replicas where failover_mode=0 and group_id = b.group_id 
and replica_server_name <> b.primary_replica) as Secondary_replica
,(select name from sys.server_principals where principal_id in ( select principal_id from sys.endpoints where name = 'Hadr_endpoint')) as AlwaysOnAdminUser
,(Select dns_name from sys.availability_group_listeners where  group_id = b.group_id) as lsn_Name
FROM sys.availability_groups A 
JOIN sys.dm_hadr_availability_group_states b
on a.group_id = b.group_id

