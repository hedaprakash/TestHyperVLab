#Install-Module -Name SqlServer
#Get-Module SqlServer -ListAvailable
#Install-Module -Name SqlServer -Scope CurrentUser

Import-Module failoverclusters

$AllDNSToCheck=@("vw19db1","vw19db2","vw19db3","cw19db","lw19db","vw19app")
$filter = 'Address="' + ($AllDNSToCheck.trim() -join '" or Address="') + '"'

$Checkdbaccesible="
update a set col1 =getdate()
from vW19db1TestDB..tbltest a"


$getdbhealthquery="
select @@servername as HostName, db_name(database_id) is_primary_replica,synchronization_state_desc,synchronization_health_desc,database_state_desc
,(select top 1 role_desc FROM sys.dm_hadr_availability_replica_states ars where replica_id = a.replica_id) as Role
FROM sys.dm_hadr_database_replica_states a where is_local=1

"
while (1 -eq 1)
{
    Try
    {

    $AllServerStatus=Get-WmiObject -Class Win32_PingStatus -Filter $filter | Select-Object @{Name="Time";Expression={Get-Date -format "HH:mm:ss"}},@{Name="DestinationHost";Expression={$_.Address}}, IPV4Address,@{Name="Status";Expression={if ($_.StatusCode -eq 0){"UP"} else {"Down"}}} | Sort-Object -Property DestinationHost
    $AllServerStatus| add-member -membertype noteproperty -name  ClusterNode -value ""
    $AllServerStatus| add-member -membertype noteproperty -name  ClusterValue -value ""
    $AllServerStatus| add-member -membertype noteproperty -name  AGProperty -value ""
    $AllServerStatus| add-member -membertype noteproperty -name  AGValue -value ""
    $AllServerStatus| add-member -membertype noteproperty -name  DBProperty -value ""
    $AllServerStatus| add-member -membertype noteproperty -name  DB1 -value ""
    $AllServerStatus| add-member -membertype noteproperty -name  DB2 -value ""
    $AllServerStatus| add-member -membertype noteproperty -name  DB3 -value ""

#$ClusterName = "cw19db"
#$ClusterOwner =(Get-Cluster | ? {$_.Name -eq $ClusterName} | Get-ClusterGroup  | where-object {$_.name -like "Cluster Group"} |select -ExpandProperty OwnerNode).Name


    if(($AllServerStatus| where {$_.DestinationHost -eq "lw19db"}).status -eq "up")
    {
        try
        {
            $errormsg=$null
            $lsndbaccesibleStatus="True"
            try{Invoke-Sqlcmd -ServerInstance lw19db  -Query $Checkdbaccesible  -ErrorAction Stop } catch {$errormsg=($_.exception.message)}
            if (($errormsg -match "Failed to update database") -or ($errormsg -match "Unable to access availability database"))
            {
                $lsndbaccesibleStatus="False"
            }
            
            $AlwaysOnQuery="
                SELECT  @@servername as HostName, a.name as avggroup,b.primary_replica
                ,(select top 1  replica_server_name from sys.availability_replicas where failover_mode=0 and group_id = b.group_id 
                and replica_server_name <> b.primary_replica) as Secondary_replica
                ,(select  top 1 name from sys.server_principals where principal_id in ( select principal_id from sys.endpoints where name = 'Hadr_endpoint')) as AlwaysOnAdminUser
                ,(Select  top 1 dns_name from sys.availability_group_listeners where  group_id = b.group_id) as lsn_Name
                ,LSN_DB_accesible='$lsndbaccesibleStatus'
                FROM sys.availability_groups A 
                JOIN sys.dm_hadr_availability_group_states b
                on a.group_id = b.group_id
                "
            #$AlwaysOnQuery

            $AlwaysOnStatus=Invoke-Sqlcmd -ServerInstance lw19db  -Query $AlwaysOnQuery  -ErrorAction Stop 
        
            $AllServerStatus[0].AGProperty="LsnHostName"
            $AllServerStatus[0].AGValue=$AlwaysOnStatus[0]

            $AllServerStatus[1].AGProperty="avggroup"
            $AllServerStatus[1].AGValue=$AlwaysOnStatus[1]

            $AllServerStatus[2].AGProperty="primary_replica"
            $AllServerStatus[2].AGValue=$AlwaysOnStatus[2]

            $AllServerStatus[3].AGProperty="Secondary_replica"
            $AllServerStatus[3].AGValue=$AlwaysOnStatus[3]

            $AllServerStatus[4].AGProperty="lsn_Name"
            $AllServerStatus[4].AGValue=$AlwaysOnStatus[5]

            $AllServerStatus[5].AGProperty="lsnDBconnect"
            $AllServerStatus[5].AGValue=$AlwaysOnStatus[6]

            $GetClusterNodes="select member_name,member_state_desc,number_of_quorum_votes from sys.dm_hadr_cluster_members"
            try{$GetClusterNodes=Invoke-Sqlcmd -ServerInstance lw19db -Query $GetClusterNodes  -ErrorAction Stop } catch {write-host "Failed while getting cluster nodes info `n$($_.exception.message)"}
            if ($GetClusterNodes)
            {
                $AllServerStatus[0].ClusterNode=$GetClusterNodes[0].member_name
                $AllServerStatus[0].ClusterValue=$GetClusterNodes[0].member_state_desc
                $AllServerStatus[1].ClusterNode="Quorum"
                $AllServerStatus[1].ClusterValue=$GetClusterNodes[0].number_of_quorum_votes
                $AllServerStatus[2].ClusterNode=$GetClusterNodes[1].member_name
                $AllServerStatus[2].ClusterValue=$GetClusterNodes[1].member_state_desc
                $AllServerStatus[3].ClusterNode="Quorum"
                $AllServerStatus[3].ClusterValue=$GetClusterNodes[1].number_of_quorum_votes
                $AllServerStatus[4].ClusterNode=$GetClusterNodes[2].member_name
                $AllServerStatus[4].ClusterValue=$GetClusterNodes[2].member_state_desc
                $AllServerStatus[5].ClusterNode="Quorum"
                $AllServerStatus[5].ClusterValue=$GetClusterNodes[2].number_of_quorum_votes
            }
        } catch {write-host "Error while fetching details from listener from lw19db `n($($_.exception.message))"}

        
    }

    $AllServerStatus[0].DBProperty="HostName"
    $AllServerStatus[1].DBProperty="is_primary_replica"
    $AllServerStatus[2].DBProperty="synchronization_state_desc"
    $AllServerStatus[3].DBProperty="synchronization_health_desc"
    $AllServerStatus[4].DBProperty="database_state_desc"
    $AllServerStatus[5].DBProperty="Role"
    

    $dbhealthStatus=$null
    $GetdbHealth=@()
    $DestinationHost="vw19db1"
    if(($AllServerStatus| where {$_.DestinationHost -eq $DestinationHost}).status -eq "up")
    {
        try{
        $dbhealthStatus=Invoke-Sqlcmd -ServerInstance $DestinationHost -Query $getdbhealthquery   -ErrorAction Stop 
            if (!([string]::IsNullOrEmpty($dbhealthStatus)))
            {
                $AllServerStatus[0].DB1=$dbhealthStatus[0]
                $AllServerStatus[1].DB1=$dbhealthStatus[1]
                $AllServerStatus[2].DB1=$dbhealthStatus[2]
                $AllServerStatus[3].DB1=$dbhealthStatus[3]
                $AllServerStatus[4].DB1=$dbhealthStatus[4]
                $AllServerStatus[5].DB1=$dbhealthStatus[5]
            }else{write-host "Able to connect to sql serevr on $DestinationHost, db details are empty"}
        } catch {write-host "Error while database health from $DestinationHost `n($($_.exception.message))"}
    }
    $DestinationHost="vw19db2"
    if(($AllServerStatus| where {$_.DestinationHost -eq $DestinationHost}).status -eq "up")
    {
        try{
        $dbhealthStatus=Invoke-Sqlcmd -ServerInstance $DestinationHost -Query $getdbhealthquery  -ErrorAction Stop 
            if (!([string]::IsNullOrEmpty($dbhealthStatus)))
            {
                $AllServerStatus[0].DB2=$dbhealthStatus[0]
                $AllServerStatus[1].DB2=$dbhealthStatus[1]
                $AllServerStatus[2].DB2=$dbhealthStatus[2]
                $AllServerStatus[3].DB2=$dbhealthStatus[3]
                $AllServerStatus[4].DB2=$dbhealthStatus[4]
                $AllServerStatus[5].DB2=$dbhealthStatus[5]
            }else{write-host "Able to connect to sql serevr on $DestinationHost, db details are empty"}
        } catch {write-host "Error while database health from $DestinationHost `n($($_.exception.message))"}

    }

    $DestinationHost="vw19db3"
    if(($AllServerStatus| where {$_.DestinationHost -eq $DestinationHost}).status -eq "up")
    {
        try{
        $dbhealthStatus=Invoke-Sqlcmd -ServerInstance $DestinationHost -Query $getdbhealthquery  -ErrorAction Stop 
            if (!([string]::IsNullOrEmpty($dbhealthStatus)))
            {
                $AllServerStatus[0].DB3=$dbhealthStatus[0]
                $AllServerStatus[1].DB3=$dbhealthStatus[1]
                $AllServerStatus[2].DB3=$dbhealthStatus[2]
                $AllServerStatus[3].DB3=$dbhealthStatus[3]
                $AllServerStatus[4].DB3=$dbhealthStatus[4]
                $AllServerStatus[5].DB3=$dbhealthStatus[5]
            }else{write-host "Able to connect to sql serevr on $DestinationHost, db details are empty"}
        } catch {write-host "Error while database health from $DestinationHost `n($($_.exception.message))"}
    }

        $AllServerStatus| ft -Property Time,DestinationHost,IPV4Address,Status,ClusterNode,ClusterValue,AGProperty,AGValue,DBProperty,DB1,DB2,DB3 -Wrap
    }
    Catch
    {
        $AllServerStatus| ft -Property Time,DestinationHost,IPV4Address,Status,ClusterNode,ClusterValue,AGProperty,AGValue,DBProperty,DB1,DB2,DB3 -Wrap
        $_.exception.message
    }
    Start-Sleep -s 3

}


