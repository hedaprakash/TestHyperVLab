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
exit

$VMName ="vW19db1"
#$VMName ="vW19db2"
#$VMName ="vW19db3"
#$VMName ="vW19app"
$AdministratorPassword="tttttt1!"

if ($VMName -eq "vW19db3")
    {$NewSwitchName="Lan20"} 
else 
    {$NewSwitchName="Lan10"}

$OSvhdx="C:\VHD\$($VMName).vhdx"
New-VHD  -Path $OSvhdx -ParentPath "C:\VHD\vW19Parent.vhdx"  -SizeBytes 250GB   | Out-Null
$Drive = (Mount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue -PassThru | Get-Disk | Get-Partition).DriveLetter
$Drive =$Drive | select -last 1

$unattennded = $unattenndedbase -replace "VMNamexxx",$VMName -replace "AdministratorPasswordxxx",$AdministratorPassword
$unattennded | Out-File "$Drive`:\unattend.xml"  -Encoding ASCII

Dismount-VHD -Path $OSvhdx -ErrorAction SilentlyContinue

New-VM -Name "$($VMName)" -SwitchName $NewSwitchName -VHDPath "C:\VHD\$($VMName).vhdx"
Set-VMProcessor -VMName "$($VMName)" -Count 1
Set-VMMemory -VMName "$($VMName)" -DynamicMemoryEnabled $true -MinimumBytes 512MB -MaximumBytes 4096MB -Buffer 20  -StartupBytes 2048MB
Enable-VMIntegrationService -Name "Guest Service Interface" -VMName $($VMName)
Set-VM -VMName "$($VMName)" -AutomaticCheckpointsEnabled $False
Set-VMDvdDrive -VMName $VMName -Path "D:\SQLSetup.iso"
Set-VM -Name $VMName -AutomaticStartAction Nothing
Set-VM -Name $VMName -AutomaticStopAction turnoff

start-sleep -s 2

Start-VM  "$($VMName)"
vmconnect localhost $($VMName)
