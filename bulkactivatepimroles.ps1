#user input for variables
    [int]$DurationInHours = Read-Host -Prompt 'Provide number of hours to activate Azure AD privileged roles - Max is 8 hours. If you only need the roles activated for less than 8 hours please enter a smaller value'
    if ($DurationInHours -gt 8) {
        Write-Host 'Number of hours to activate Azure AD privileged roles is greater than 8, please run script again with a valid value' -ForegroundColor Yellow
        Start-Sleep -s 7
        Exit    
    }
    $Reason = Read-Host -Prompt 'Provide reason to activate roles, for example - Daily PIM activation for BAU tasks'

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

    #please wait note fore user
    Write-Host 'Please wait while script attempts to activate your Azure AD privileged roles'

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


    

