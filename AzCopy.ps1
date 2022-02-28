$TempPath =  "c:\Temp\Software"

try {
    If (!(Test-path -Path $TempPath -ErrorAction Ignore)) {New-Item -ItemType Directory $TempPath }
} catch 
{
$ErrorMessage = $_.Exception.message
Write-Output "Error creating temp folder $ErrorMessage"
}

If (!(Test-Path -Path $LogPath -ErrorAction Ignore)) {New-Item -ItemType Directory $LogPath }

$zip = "$TempPath\AzCopy.Zip"
Start-BitsTransfer -Source "https://aka.ms/downloadazcopy-v10-windows" -Destination $zip
Expand-Archive $zip $TempPath -Force


