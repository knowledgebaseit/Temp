<#

#>

#region Variables
$TempPath =  "c:\Temp\Software"
$LogPath = "C:\Programdata\PPC\"
$Logfile = "Software_Install.log"
#repo for app installation parameters
$repo = "https://dev.azure.com/ProactBenelux/d4523fbb-bde0-48ff-9be6-e3fb84165b1a/_apis/git/repositories/92abb40d-73cf-49ef-9a5c-cbed18018b12/items?path="
$storageaccount = "https://ppcavdstorage.blob.core.windows.net/avdbuild?sp=r&st=2022-02-24T08:31:07Z&se=2023-02-24T16:31:07Z&spr=https&sv=2020-08-04&sr=c&sig=8NGsByN%2BkHPpTsFIZvRubQ%2FqfN1c1Hig7pDAyqXmZfo%3D"

#Module to install
$Modules=@()
$Modules+="Evergreen"

#Software Language and Platform
$Language=@()
$Language+="NL"
$Language+="Dutch"

$Architecture=@()
$Architecture+="x64"
$Architecture+="AMD64"

#To add software add the AppName tot the variable list
#you can obtain Appnames via Find-EvergreenApp | select name
$SoftwareToDownload=@()
$SoftwareToDownload+="GoogleChrome"
#$SoftwareToDownload+="AdobeAcrobatReaderDC"
#$SoftwareToDownload+="MozillaFirefox"
#$SoftwareToDownload+="MicrosoftEdge"
#$SoftwareToDownload+="MicrosoftEdgeWebView2Runtime"
#$SoftwareToDownload+="MicrosoftTeams"
#$SoftwareToDownload+="MicrosoftOneDrive"
#$SoftwareToDownload+="OracleJava8"
#$SoftwareToDownload+="NotepadPlusPlus"
#$SoftwareToDownload+="MicrosoftWvdRemoteDesktop"
#$SoftwareToDownload+="MicrosoftWvdRtcService"
#$SoftwareToDownload+="MicrosoftFSLogixApps"

#endregion
#region create folders
#Create folder for Logfile storage
#Create Temp folder for Software download and Extract
try {
        If (!(Test-path -Path $TempPath -ErrorAction Ignore)) {New-Item -ItemType Directory $TempPath }
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error creating temp folder $ErrorMessage"
}

If (!(Test-Path -Path $LogPath -ErrorAction Ignore)) {New-Item -ItemType Directory $LogPath }

#Create folder for Languagefile storage
try {
        $LanguagePath=$TempPath+"\nl"
        If (!(Test-Path -Path $LanguagePath -ErrorAction Ignore)) {New-Item -ItemType Directory $LanguagePath}

}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error creating Log folder $ErrorMessage"
}
#endregion create folders
#region AZCopy
$zip = "$TempPath\AzCopy.Zip"
Start-BitsTransfer -Source "https://aka.ms/downloadazcopy-v10-windows" -Destination $zip
Expand-Archive $zip $TempPath -Force
$azcopy = (get-childitem -Path $TempPath -Include "azcopy.exe" -Recurse)

# download application files from storage account
start-process -FilePath $azcopy.FullName -ArgumentList "cp $storageaccount $temppath --recursive=true"
#endregion
#region prerequisites
Write-Host "Installing NuGet package provider and setting PSGallery to Trusted"
If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Get-packageprovider -name "NuGet" -ForceBootstrap
    Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
}
#endregion prerequisites
#region install modules
Write-Host "Installing Required Powershell modules"
foreach ($module in $modules) {

$Installed = Get-Module -Name "$Module" -ListAvailable | `
    Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | `
    Select-Object -First 1
$Published = Find-Module -Name "$Module"
If ($Null -eq $Installed) {
    Write-Host "Module $Module not found, proceed to install"
    Install-Module -Name "$Module"
}
ElseIf ([System.Version]$Published.Version -gt [System.Version]$Installed.Version) {
    Write-Host "Module $Module not up to date, proceed to update to currentversion"
    Update-Module -Name "$Module"
    }
    Else {Write-Host "Module $Module is up to date, proceed to next module or downloads."}
}
#endregion install modules
#region download software
foreach ($app in $SoftwareToDownload) {

#retrieve criteria file needed to select proper Evergreen packages
Write-Host "Downloading criteria file for $app"
$loadparamfile=(Invoke-WebRequest -Uri "$repo/$app/criteria.txt" -UseBasicParsing -Verbose).content
If ([string]::IsNullOrEmpty($loadparamfile)){
Write-host "No download criteria defined for $app please fix"
Exit 1 } else {
Invoke-Expression $loadparamfile

$param=Get-Variable ("$app"+'Param') -ValueOnly
Write-Host "Searching $app file using criteria $param"

$AppParams = @{
    Name = $app
}
if ($app -eq "MozillaFirefox") {
    $AppParams.AppParams = @{Language = "nl"}
}

$Application = Get-EvergreenApp @AppParams |
               Where-Object $param |
               Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } |
               Select-Object -First 1

}

Write-Host "Downloading $application.name $application.version"
$application | Save-EvergreenApp -Path "$TempPath\$app"

#Passing Applications details to new variable for reuse during installation or upload
New-Variable -Name "DetailsOf$app" -Value (
[PSCustomObject]@{
    Name     = $application.name
    Version = $application.version
    URI    = $application.uri
       } ) -ErrorAction SilentlyContinue
    }
#endregion download software
#region EvergreenApp Installation routine

#Gather Required parameter files needed to create Intune Packages
foreach ($app in $SoftwareToDownload) {

$installerfile=Get-childitem -Path "$TempPath\$app\*" -Include *.exe, *.msi, *.zip -Recurse
$SetupFile=$installerfile.fullname

#Obtain installation preparation file from repo
Write-Host "Downloading preparation file for $app from $repo/$app/preparation.txt"
If (!([string]::IsNullOrEmpty($preparation))){Remove-Variable -name preparation -ErrorAction SilentlyContinue}
$preparation=(Invoke-WebRequest -Uri "$repo/$app/preparation.txt" -UseBasicParsing -Verbose).content
If ($preparation -ne "") {
Invoke-Expression $preparation -Verbose }
else { Write-host "No preparation file defined for $app" }

#Obtain installation parameters
Write-Host "Downloading installparameters file for $app from $repo/$app/installparameters.txt"
If (!([string]::IsNullOrEmpty($installparameters))){Remove-Variable -name installparameters -ErrorAction SilentlyContinue}
$installparameters=(Invoke-WebRequest -Uri "$repo/$app/installparameters.txt" -UseBasicParsing -Verbose).content
If ($installparameters -ne "") {
Invoke-Expression $installparameters -Verbose }
else { Write-host "No installparameters file defined for $app" }

#Process downloaded installers & install them silently, gather log file for MSI installations
$Installparam=Get-Variable ("$app"+'_InstallerCMD') -ValueOnly

try {
if($SetupFile -like "*.msi") {
$MsiLog = $LogPath+"$app"+'_msilog_'+ (Get-Date -Format "dd-MM-yyyy-HHmmss") +".log"
$MsiArguments = "/i `"$SetupFile`" $Installparam ALLUSERS=1 reboot=reallysuppress /qn /l*v `"$MsiLog`""

Write-Host "Installing $App as using Arguments $MSIArguments"
Start-Process -FilePath C:\Windows\System32\msiexec.exe -ArgumentList $MsiArguments -Wait
 }
elseif ($SetupFile -like "*.exe") {
Write-Host "Installing $App as using Arguments $Installparam"
Start-Process -FilePath $SetupFile -ArgumentList $Installparam -Wait
    }
}
catch {
    $errorMsg = $_.Exception.Message
    Write-Host $errorMsg
    }
}

#endregion App Installation routine
