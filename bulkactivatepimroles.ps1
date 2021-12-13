param (
        [int]$DurationInHours = 8,
        $Reason = "Daily PIM elevation"
    )

#Check for Azure AD Preview Module is installed
If (-Not ( Get-Module -ListAvailable 'AzureADPreview' ).path){
    Write-Host "The Azure AD Privileged Identity Management Module is not installed, we will try to install it now" -ForegroundColor Yellow
    write-Host "This will only work if you are running this script as Local Administrator" -ForegroundColor Yellow
    Write-Host
    
    #Check if the script runs in an local Administrator context
    If ($(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $True)
        {Install-Module AzureADPreview } 
    
    #Exit if PowerShell if not running as admin
    Else
    {Write-Host "You are not running the script as Local Admin. The script will exit now" -ForegroundColor Yellow
    Exit}}

#Fucntion to activate each available PIM role for user
Function Activate {
Open-AzureADMSPrivilegedRoleAssignmentRequest -ProviderId aadRoles -Schedule $schedule -ResourceId $AzureADCurrentSessionInfo.TenantId -RoleDefinitionId $CurrentRole.RoleDefinitionId -SubjectId $AadResponse.UniqueID -AssignmentState "Active" -Type "UserAdd" -Reason $Reason}

try {

    $AzureADCurrentSessionInfo = AzureADPreview\Get-AzureADCurrentSessionInfo -ErrorAction Stop

}

catch {
    # Get token for MS Graph by prompting for MFA (note: ClientId 1b730954-1685-4b74-9bfd-dac224a7b894 = Azure PowerShell)
    $MsResponse = Get-MSALToken -Scopes @("https://graph.microsoft.com/.default") -ClientId "1b730954-1685-4b74-9bfd-dac224a7b894" -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -Authority "https://login.microsoftonline.com/common" -Interactive -ExtraQueryParameters @{claims = '{"access_token" : {"amr": { "values": ["mfa"] }}}' } -ErrorAction Stop

    # Get token for AAD Graph
    $AadResponse = Get-MSALToken -Scopes @("https://graph.windows.net/.default") -ClientId "1b730954-1685-4b74-9bfd-dac224a7b894" -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -Authority "https://login.microsoftonline.com/common" -ErrorAction Stop

    AzureADPreview\Connect-AzureAD -AadAccessToken $AadResponse.AccessToken -MsAccessToken $MsResponse.AccessToken -AccountId: $AadResponse.Account.Username -tenantId: $AadResponse.TenantId -ErrorAction Stop

    $AzureADCurrentSessionInfo = AzureADPreview\Get-AzureADCurrentSessionInfo

    #Get all roles available to user to activate
    $CurrentRoles = Get-AzureADMSPrivilegedRoleAssignment -ProviderId aadRoles -ResourceId $AzureADCurrentSessionInfo.TenantId -ErrorAction Stop | Where-Object {$_.SubjectId -eq $AadResponse.UniqueID} | Where-Object {$_.AssignmentState -eq "Eligible" }

}
#varaibles for activation window
$schedule = New-Object Microsoft.Open.MSGraph.Model.AzureADMSPrivilegedSchedule
$schedule.Type = "Once"
$schedule.StartDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$schedule.EndDateTime = (Get-Date).AddHours($DurationInHours).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")


foreach ($currentRole in $CurrentRoles) {
    Activate
}


    

