# --------------------
# Parameters
# --------------------
[cmdletbinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The file name for the JSON file that will be exported to /outputs/json")][ValidateNotNullOrEmpty()]
    [string] $JsonFileName
)


# --------------------
# Functions
# --------------------
Function Invoke-MgGraphAPI {
    # version 2.2
    # https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0#using-invoke-mggraphrequest
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [String]$Method,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [String]$Endpoint,
        [Parameter(Mandatory = $false)]
        $Body
    )
    $URI = "https://graph.microsoft.com/" + $Endpoint
    $Data = [System.Collections.Generic.List[Object]]@()
    try {
        switch ($Method) {
            "GET" {
                do {
                    $Response = Invoke-MgGraphRequest -Method $Method -Uri $URI -ContentType "application/json"
                    # if $Response contains multiple objects
                    if ($null -ne $Response.Value) {
                        $Data.AddRange($Response.value) 
                        # if $Response contains '@odata.nextLink' - paging
                        if ($Response.'@odata.nextLink') {
                            $URI = $Response.'@odata.nextlink'
                        } 
                        else {
                            $URI = $null
                        }              
                    }
                    # $Response contains a single object
                    else {
                        $Data.Add($Response)
                        $URI = $null
                    }
                } until ($null -eq $URI)     
                return $Data
            }
            "POST" {
                $Body = $Body | ConvertTo-Json
                $Response = Invoke-MgGraphRequest -Method $Method -Uri $URI -Body $Body -ContentType "application/json"
                return $Response
            }
            "PUT" {}
            "PATCH" {
                $Body = $Body | ConvertTo-Json
                $Response = Invoke-MgGraphRequest -Method $Method -Uri $URI -Body $Body -ContentType "application/json"
                return $Response
            }
            "DELETE" {
                $Response = Invoke-MgGraphRequest -Method $Method -Uri $URI
                return $Response
            }
        }    
    }
    catch {
        Write-Host -ForegroundColor Red "Exception type: $($_.Exception.GetType().FullName)"
        Write-Host -ForegroundColor Red "Exception message: $($_.Exception.Message)"
    }
}

# --------------------
# Objects
# --------------------
class Destination {
    [String]$Name
    [String]$DisplayName
    [String]$Group
}
class PolicyRule {
    [String]$Id
    [String]$Name
    [String]$RuleType
    [System.Collections.ArrayList]$Destinations
}
class Policy {
    [String]$Id
    [String]$Name
    [String]$Description
    [String]$Version
    [String]$LastModifiedDateTime
    [String]$CreatedDateTime
    [String]$Action
    [System.Collections.ArrayList]$PolicyRules
}
class FilteringPolicyLink {
    [String]$Id
    [Int]$Priority
    [String]$State
    [String]$Version
    [Policy]$Policy
}

class FilteringProfile {
    [String]$Id
    [String]$Name
    [String]$Description
    [String]$Version
    [String]$State
    [String]$LastModifiedDateTime
    [Int]$Priority
    [String]$CreatedDateTime
    [System.Collections.ArrayList]$PolicyLinks
    [System.Collections.ArrayList]$IncludedUsers
    [System.Collections.ArrayList]$IncludedGroups
}


# --------------------
# Authentication
# --------------------
Write-Host "Authenticating..." -ForegroundColor Gray
Connect-MgGraph -Scopes NetworkAccess.Read.All, Group.Read.All, User.Read.All, Policy.Read.ConditionalAccess -ContextScope Process > $null


# --------------------
# Program
# --------------------
$jsonFilePath = ".\outputs\json\$JsonFileName"

Write-Host "Retrieving policies..." -ForegroundColor Gray
$JsonArray = [System.Collections.ArrayList]::new()

# Get all Conditional Access policies which we can use later
$CaPolicies = Invoke-MgGraphAPI -Method "GET" -Endpoint "beta/identity/conditionalAccess/policies"

# Get all Filtering Profiles
$ListFilteringProfile = Invoke-MgGraphAPI -Method "GET" -Endpoint "beta/networkAccess/filteringProfiles"

foreach ($Profile in $ListFilteringProfile) {
    # Save each filtering profile as a new object
    $FilteringProfile = [FilteringProfile]::new()
    $FilteringProfile.Id = $Profile.id
    $FilteringProfile.Name = $Profile.name
    $FilteringProfile.Description = $Profile.description
    $FilteringProfile.Version = $Profile.version
    $FilteringProfile.State = $Profile.state
    $FilteringProfile.LastModifiedDateTime = $Profile.lastModifiedDateTime
    $FilteringProfile.CreatedDateTime = $Profile.createdDateTime
    $FilteringProfile.Priority = $Profile.priority
    $FilteringProfile.PolicyLinks = [System.Collections.ArrayList]::new()
    $FilteringProfile.IncludedUsers = [System.Collections.ArrayList]::new()
    $FilteringProfile.IncludedGroups = [System.Collections.ArrayList]::new()

    # Search for the conditional access policies related to this security profile
    foreach ($CaPolicy in $CaPolicies) {
        if ($CaPolicy.sessionControls.globalSecureAccessFilteringProfile.profileId -eq $Profile.id) {
            # Save users in Filter Profile by requesting UPN
            $UserList = [System.Collections.ArrayList]::new()
            foreach ($UserId in $CaPolicy.conditions.users.includeUsers) {
                $UserInfo = Invoke-MgGraphAPI -Method "GET" -Endpoint "beta/users/$UserId"
                $UserList.Add($UserInfo.userPrincipalName) | Out-Null
            }

            # Save groups in Filter Profile by requesting group display name
            $GroupList = [System.Collections.ArrayList]::new()
            foreach ($GroupId in $CaPolicy.conditions.users.includeGroups) {
                $GroupInfo = Invoke-MgGraphAPI -Method "GET" -Endpoint "beta/groups/$GroupId"
                $GroupList.Add($GroupInfo.displayName) | Out-Null
            }

            # Saving the objects to policy object
            $FilteringProfile.IncludedUsers = $UserList
            $FilteringProfile.IncludedGroups = $GroupList
        }
    }

    if ($FilteringProfile.Name -eq "Baseline Profile") { 
        $FilteringProfile.IncludedUsers.Add("All Users") | Out-Null 
        $FilteringProfile.IncludedGroups.Add("All Users") | Out-Null 
    }
    if ($FilteringProfile.IncludedUsers.Count -eq 0) { $FilteringProfile.IncludedUsers.Add("None") | Out-Null }
    if ($FilteringProfile.IncludedGroups.Count -eq 0) { $FilteringProfile.IncludedGroups.Add("None") | Out-Null }

    $ListPolicyLinks = Invoke-MgGraphAPI -Method "GET" -Endpoint "beta/networkaccess/filteringProfiles/$($FilteringProfile.Id)/policies"

    foreach ($Link in $ListPolicyLinks) {
        # Create Policy object since it is used in the Link object
        $Policy = [Policy]::new()
        $Policy.Id = $Link.policy.id
        $Policy.Name = $Link.policy.name
        $Policy.Description = $Link.policy.description
        $Policy.Version = $Link.policy.version
        $Policy.LastModifiedDateTime = $Link.policy.lastModifiedDateTime
        $Policy.CreatedDateTime = $Link.policy.createdDateTime
        $Policy.Action = $Link.policy.action
        $Policy.PolicyRules = [System.Collections.ArrayList]::new()

        # Create Link object between the Profiles and the Policies
        $PolicyLink = [FilteringPolicyLink]::new()
        $PolicyLink.Id = $Link.id
        $PolicyLink.Priority = $Link.priority
        $PolicyLink.State = $Link.state
        $PolicyLink.Version = $Link.version
        $PolicyLink.Policy = $Policy

        $ListPolicyRules = Invoke-MgGraphAPI -Method "GET" -Endpoint "beta/networkaccess/filteringPolicies/$($Policy.Id)?`$expand=policyRules"
        foreach ($Rule in $ListPolicyRules.policyRules) {
            $PolicyRule = [PolicyRule]::new()
            $PolicyRule.Id = $Rule.id
            $PolicyRule.Name = $Rule.name
            $PolicyRule.RuleType = $Rule.ruleType
            $PolicyRule.Destinations = $Rule.destinations

            $Policy.PolicyRules.Add($PolicyRule) | Out-Null
        }

        $FilteringProfile.PolicyLinks.Add($PolicyLink) | Out-Null
    }

    $JsonArray.Add($FilteringProfile) | Out-Null
}


$directory = [System.IO.Path]::GetDirectoryName($jsonFilePath)
if (-not (Test-Path $directory)) {
    Write-Output "Created path $directory"
    New-Item -ItemType Directory -Path $directory | Out-Null
}
$JsonArray | ConvertTo-Json -Depth 10 | Out-File "$jsonFilePath" -Force

Write-Output "JSON policy file generated and saved at $jsonFilePath"