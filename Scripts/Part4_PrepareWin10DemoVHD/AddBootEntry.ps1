# bcdedit /import C:\SQLSetup\Scripts\Part4_PrepareWin10DemoVHD\OrigBCD_20290911.bkp

$BootOrigBackupFile = "C:\SQLSetup\Scripts\Part4_PrepareWin10DemoVHD\OrigBCD_20290912.bkp"

bcdedit /export $BootOrigBackupFile
write-output  "Restore Boot entry"
write-output  ("bcdedit /import " + $BootOrigBackupFile)



$SettingsBase=@"
<Settings>
	<BootEntry Drive="C" Path="BootVHD\w10Demo\w10Demo.vhdx" Description="w10Demo" />
</Settings>
"@

bcdedit /enum
$settings = ([xml]$SettingsBase).settings
$BootEntry = $settings.BootEntry
$Drive = $BootEntry.Drive
$Path = $BootEntry.Path
$Description = $BootEntry.Description
$VHD = 'vhd=[' + $Drive + ':]\' + $Path

$BootEntry 
$Description 
$VHD 

$BootEntryCopy = bcdedit /copy '{current}' /d $BootEntry.Description
#Parsing New Boot Entry GUID "
$CLSID = $BootEntryCopy | ForEach-Object {$_.Remove(0,37).Replace(".","")} 
#New Boot Entry GUID 
bcdedit /set $CLSID device $VHD
bcdedit /set $CLSID osdevice $VHD
bcdedit /set $CLSID detecthal on
bcdedit /enum

exit
write-output  "Restore Boot entry"
write-output  ("bcdedit /import " + $BootOrigBackupFile)
