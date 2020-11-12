exit
$vmname="vW19db1" 
[string] $Adminaccount="sqlfeatures\hvadmin"
[string] $AdminPassword="tttttt1!"
$secretAdminpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Adminaccount, $secretAdminpassword
Enter-PSSession -vmName $vmname -Credential $credential #-Authentication Credssp

$NodeName= $env:COMPUTERNAME
"Validate AlwaysOn Enabled on $NodeName..." | Write-Host
invoke-sqlcmd -ServerInstance $NodeName  -Query "set nocount on;select @@servername as DBServerName, @@version as SQLVersion,SERVERPROPERTY('productversion') as Version, SERVERPROPERTY ('edition') as Edition,serverproperty('IsHadrEnabled') as IsHadrEnabled" -Verbose  -ErrorAction Stop 

"Enable AlwaysON on SQL Service" | Write-Host
Enable-SqlAlwaysOn -ServerInstance $NodeName -Force


"Restarting sql server on $NodeName now..." | Write-Host
Get-Service -ComputerName $NodeName -name MSSQLSERVER -ErrorAction SilentlyContinue| Restart-Service -force
Get-Service -ComputerName $NodeName -name SQLSERVERAGENT -ErrorAction SilentlyContinue| Restart-Service -force

"Validate AlwaysOn Enabled on $NodeName..." | Write-Host
invoke-sqlcmd -ServerInstance $NodeName  -Query "set nocount on;select @@servername as DBServerName, @@version as SQLVersion,SERVERPROPERTY('productversion') as Version, SERVERPROPERTY ('edition') as Edition,serverproperty('IsHadrEnabled') as IsHadrEnabled" -Verbose  -ErrorAction Stop 

# To be executed only for node 1
[string]$AlwaysOnShareFolder = "C:\AlwaysOnShare"
[string]$AlwaysONShareName = "AlwaysOnShare"

$GetSQLServiceAccountName=Get-WmiObject win32_service  -filter "name='MSSQLSERVER'" | select name,startname
$SQLStartupAccount=$GetSQLServiceAccountName.startname

if(!(test-path $AlwaysOnShareFolder)){[IO.Directory]::CreateDirectory($AlwaysOnShareFolder)}

" net share $AlwaysONShareName=$AlwaysOnShareFolder /GRANT:$SQLStartupAccount`,FULL /GRANT:$localUserName`,FULL "| Write-Host
net share
net share $AlwaysONShareName=$AlwaysOnShareFolder /GRANT:$SQLStartupAccount`,FULL /GRANT:$localUserName`,FULL
net share
#net share AlwaysOnShare /Delete

$dbname=$vmname+"testdb"
invoke-sqlcmd -ServerInstance $NodeName  -Query "if db_id('$dbname') is not null drop database [$dbname] 
create database [$dbname]
" -Verbose  -ErrorAction Stop 

invoke-sqlcmd -ServerInstance $NodeName  -Query "
BACKUP DATABASE [$dbname] TO  DISK = N'$AlwaysOnShareFolder\$dbname.bak' WITH NOFORMAT, NOINIT,  NAME = N'$dbname-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
BACKUP LOG [$dbname] TO  DISK = N'$AlwaysOnShareFolder\$dbname_log.bak' WITH NOFORMAT, NOINIT,  NAME = N'$dbname-Log  Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
" -Verbose  -ErrorAction Stop 



<#
$alwaysOnServerIPs= "10.10.10.31,20.20.20.31" #Request network team 2 more static IPs one for each subnet

$ClusterName = "cW19db" # Cluster name should be less than 15 characters, naming convention start with c<Prd><3 digit appName>DB<1>

$avgGroupName=”aW19db” # Availability group name should be less than 15 characters, naming convention start with a<Prd><3 digit appName>DB<1>

$LsnName="lW19db" # Listener name should be less than 15 characters, naming convention start with l<Prd><3 digit appName>DB<1>

#>