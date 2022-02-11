Configuration PPC-Groups
{
    param (
        [parameter()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    if ($null -eq $Credential)
    {
        <# Credentials #>
        $Credscredential = Get-Credential -Message "Credentials"

    }
    else
    {
        $CredsCredential = $Credential
    }

    $OrganizationName = $CredsCredential.UserName.Split('@')[1]
    Import-DscResource -ModuleName 'Microsoft365DSC'

    Node localhost
    {
        AADGroup cae2b082-b9d6-4793-9d8a-20a2fa8a4e27
        {
            Credential           = $Credscredential;
            Description          = "Default Licensing group for all Users";
            DisplayName          = "LIC-MS365Default";
            Ensure               = "Absent";
            GroupTypes           = @();
            Id                   = "b1df5186-25fa-4004-8ce9-6ce6209f3449";
            MailEnabled          = $False;
            MailNickname         = "a6596c7b-0";
            SecurityEnabled      = $True;
        }
    }
}
PPC-Groups -ConfigurationData .\ConfigurationData.psd1 -Credential $Credential
