exit
$vmname="vW19db1"
[string] $Adminaccount="sqlfeatures\hvadmin"
[string] $AdminPassword="tttttt1!"
$secretAdminpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Adminaccount, $secretAdminpassword
Enter-PSSession -vmName $vmname -Credential $credential 

D:\SQLBinaries\SQL2019\EVL\Setup.exe  /SECURITYMODE=SQL /FILESTREAMLEVEL=3 /FILESTREAMSHARENAME=AdvCloudFS   /QUIET=True /ACTION=install   `
/INSTANCENAME=MSSQLSERVER /INDICATEPROGRESS=True  /SQLSVCACCOUNT="sqlfeatures\hvadmin" /SQLSVCACCOUNT="sqlfeatures\hvadmin" /AGTSVCACCOUNT="sqlfeatures\hvadmin" `
/ISSVCACCOUNT="sqlfeatures\hvadmin" /FTSVCACCOUNT="sqlfeatures\hvadmin" /AGTSVCSTARTUPTYPE=Automatic   `
/UPDATESOURCE= D:\SQLBinaries\SQL2019\SPs\CU8  /UpdateEnabled=True   /IACCEPTSQLSERVERLICENSETERMS  /SQLSYSADMINACCOUNTS="sqlfeatures\hvadmin" `
/INSTANCEDIR="C:\SQLData" /SQLBACKUPDIR="C:\SQLBackup" /SQLUSERDBLOGDIR="C:\SQLLogs" /SQLTEMPDBLOGDIR="C:\MSSQL\SQLTempDBLog" `
/SQLUSERDBDIR="C:\SQLData" /SQLTEMPDBDIR="C:\MSSQL\SQLTempDBData" /FEATURES="SQLENGINE,REPLICATION,FULLTEXT,DQ,DQC,CONN,IS,BC,SDK,SNAC_SDK,MDS" `
/SQLSVCPASSWORD="tttttt1!" /AGTSVCPASSWORD="tttttt1!" /ISSVCPASSWORD="tttttt1!" /FTSVCPASSWORD="tttttt1!" /SAPWD="tttttt1!"

Start-Sleep -S 60

D:\SQLBinaries\SQlTools\SSMS\SSMS-Setup-ENU.exe   /Install /passive /FEATURES=Adv_SSMS  /norestart /IACCEPTSQLSERVERLICENSETERMS
