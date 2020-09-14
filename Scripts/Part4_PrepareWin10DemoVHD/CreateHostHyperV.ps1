cls
Set-Location c:\
mkdir "C:\BootVHD\w10Demo"

$vhdTargetFolderVHDName= "C:\BootVHD\w10Demo\w10Demo.vhdx"
$installWindowsImageFile="C:\SQLSetup\Scripts\Part4_PrepareWin10DemoVHD\Install-WindowsImage.ps1"
$windowsSourceFolder = "E:\" 
$vhdTargetFolderVHDNameWithoutDriveLetter = $vhdTargetFolderVHDName.Substring(3)



#use diskmgmt.msc to configure VHD disk
mkdir "C:\BootVHD\w10Demo"

$FindWindowsVersion= "$installWindowsImageFile –WIM '" + $windowsSourceFolder + "\sources\install.wim'"
invoke-expression $FindWindowsVersion

$executeCommand= "$installWindowsImageFile –WIM '" + $windowsSourceFolder + "\sources\install.wim'  -Apply -Index 1 -Destination P:"
invoke-expression $executeCommand

#dismount VHD using diskmgmt.msc


