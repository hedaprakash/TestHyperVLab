$vmname="vW19db1" 
[string] $Adminaccount="sqlfeatures\hvadmin"
[string] $AdminPassword="tttttt1!"
$secretAdminpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Adminaccount, $secretAdminpassword
Enter-PSSession -vmName $vmname -Credential $credential #-Authentication Credssp

# Get-Cluster | Remove-Cluster -Force
$ClusterName = "cW19db"
$ClusterNodes="vW19db1,vW19db2,vW19db3"
$ClusterNodesArray = $ClusterNodes -split ","
New-Cluster -Name $ClusterName -Node $ClusterNodesArray -StaticAddress 10.10.10.21,20.20.20.21 -NoStorage  

    "Step1: Getting Cluster Nodes and Owner" | Write-Host
    Get-Cluster | ? {$_.Name -eq $ClusterName} | Get-ClusterGroup  | where-object {$_.name -like "Cluster Group"} 
    Get-Cluster | ? {$_.Name -eq $ClusterName} | Get-ClusterNode 

    "Step2: Checking cluster Primary owner is current node if not set it" | Write-Host
    Get-Cluster | ? {$_.Name -eq $ClusterName} | Get-ClusterGroup  | where-object {$_.name -like "Cluster Group"} 
    $ClusterGroupDetails = Get-Cluster | ? {$_.Name -eq $ClusterName} | Get-ClusterGroup  | where-object {$_.name -like "Cluster Group"} 

    "Step3: Configuring cluster owner nodes and sequence" | Write-Host
    "Current cluster owners: " | Write-Host
    Get-ClusterOwnerNode -Group $ClusterGroupDetails | select -ExpandProperty OwnerNodes
    Set-ClusterOwnerNode -Group $ClusterGroupDetails  -Owners $($ClusterNodesArray[0])
    "Updated cluster owners: " | Write-Host
    Get-ClusterOwnerNode -Group $ClusterGroupDetails | select -ExpandProperty OwnerNodes

"Default quorum setting" | Write-Host
Get-ClusterQuorum| select Cluster,QuorumResource,QuorumType 


"Looping through cluster nodes and try to make them owner" | Write-Host
$ClusterNodesFromCluster = Get-Cluster | ? {$_.Name -eq $ClusterName} | Get-ClusterNode 
$clusterSuccessful=$true
$ClusterNodesFromCluster | foreach {
        
    $ClusterGroupCurrentOwner =  (Get-Cluster | ? {$_.Name -eq $ClusterName} | Get-ClusterGroup  | where-object {$_.Name -like "Cluster Group"} |select -ExpandProperty OwnerNode).Name
    "CurrentOwner $ClusterGroupCurrentOwner, owner node to be set: $($_.Name)  "  | Write-Host
    if ($ClusterGroupCurrentOwner -ne $_.Name) 
    {
        Get-Cluster | ? {$_.Name -eq $ClusterName} | Move-ClusterGroup "Cluster Group" -Node $_.Name
        "Move completed waiting for 10 sec"  | Write-Host
        Start-Sleep -s 10
        $ClusterGroupDetails =  Get-Cluster | ? {$_.Name -eq $ClusterName} | Get-ClusterGroup  | where-object {$_.Name -like "Cluster Group"} 
        $ClusterGroupCurrentOwner =  $ClusterGroupDetails.OwnerNode.Name
        "Updated CurrentOwner $ClusterGroupCurrentOwner "  | Write-Host
        if ($ClusterGroupDetails.State -ne "Online") 
        {
            "`nCluster group failovr to node $($_.Name)  did not successfully done `nCluster is not in good health right now" | Write-Host
            "Command Move-ClusterGroup ""Cluster Group"" -Node $($_.Name) `n" | Write-Host

            $ClusterGroupDetails | Write-Host
            $clusterSuccessful=$false
        }
    }
}








<#
$ClusterNodes= "vW19db1,vW19db2,vW19db3"

$ClusterIps= "10.10.10.21,20.20.20.21" #Request network team 2 static IPs one for each subnet

$alwaysOnServerIPs= "10.10.10.31,20.20.20.31" #Request network team 2 more static IPs one for each subnet

$SubnetMask= "255.255.255.0"

#$ClusterQuorumFileShare=”\\VW19AD\ClusterQuorumFileShare” # Create a folder name ClusterQuorumFileShare on monitoring server and grant full access to everyone

$ClusterName = "cW19db" # Cluster name should be less than 15 characters, naming convention start with c<Prd><3 digit appName>DB<1>

$avgGroupName=”aW19db” # Availability group name should be less than 15 characters, naming convention start with a<Prd><3 digit appName>DB<1>

$LsnName="lW19db" # Listener name should be less than 15 characters, naming convention start with l<Prd><3 digit appName>DB<1>

# Get-Cluster | Remove-Cluster -Force

#>
