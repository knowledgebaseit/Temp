# Generated with Microsoft365DSC version 1.0.5.127
# For additional information on how to use Microsoft365DSC, please visit https://aka.ms/M365DSC
param (
    [parameter()]
    [System.Management.Automation.PSCredential]
    $GlobalAdminAccount
)

Configuration M365TenantConfig
{
    param (
        [parameter()]
        [System.Management.Automation.PSCredential]
        $GlobalAdminAccount
    )

    if ($null -eq $GlobalAdminAccount)
    {
        <# Credentials #>
        $Credsglobaladmin = Get-Credential -Message "Global Admin credentials"
    }
    else
    {
        $Credsglobaladmin = $GlobalAdminAccount
    }

    $OrganizationName = $Credsglobaladmin.UserName.Split('@')[1]
    Import-DscResource -ModuleName Microsoft365DSC

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
M365TenantConfig -ConfigurationData .\ConfigurationData.psd1 -GlobalAdminAccount $GlobalAdminAccount
