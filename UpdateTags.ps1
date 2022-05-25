######################################
## Update Resource Tag Names script ##
######################################
<#
.SYNOPSIS
    Searches and replaces Tag Key Names while preserving Tag Key Values
.DESCRIPTION
    This is a PowerShell tool that allows users to replace one or more Tag Key Names with a newly user-defined name,
    in a single operation, while preserving the original Tag Key Value.
    The tool allows users to select and replace one or more tags, across one or more accessible subscriptions.
.NOTES
    Microsoft.PowerShell.ConsoleGuiTools Module is required for all Console User Interface components
    Az.Account & Az.Resources also required.
.LINK
    Github link
.EXAMPLE
    Run the script: .\UpdateTags.ps1
#>

######################################
###### User-Defined parameters #######

# Home folder location for all log files
# Example
#   $logFilePath = "c:\"
#   $logFilePath = "\\server1\"
$logFilePath = ".\Logs\"     # current folder

######################################

# Variable Initialization
$AllTags = $null                    # Tags array
[int]$modifiedResourcesCount = 0    # Total number of resources and resource groups modified
$selectedResources = $null          # Resource array


# Log files names
$logCreationTime = Get-Date -Format "-yyyy.MM.dd-HH.mm"
$logModifiedResources = "$($logFilePath)UpdateTags-ModifiedResources$($logCreationTime).csv"                # All Resources with modified Tags
$logModifiedResourceGroups = "$($logFilePath)UpdateTags-ModifiedResourceGroups$($logCreationTime).csv"      # All Resource Groups with modified Tags
$logResourceTagErrorsFile = "$($logFilePath)UpdateTags-ResourceTagErrors$($logCreationTime).csv"
$logResourceGroupTagErrorsFile = "$($logFilePath)UpdateTags-ResourceGroupTagErrors$($logCreationTime).csv"                                # Any tagging errors that may ocurr
$logUpdateTags = "$($logFilePath)UpdateTags$($logCreationTime).log"                                         # Script Log file


# Create the required Log files if they do not exist
if ((Test-Path -Path $logFilePath) -eq $false) {
    New-Item $logFilePath -ItemType "directory"
    Write-Log "No '.\Logs' folder found. Creating new Logs folder."
}

if ((Test-Path -Path $logModifiedResources) -eq $false)         {New-Item $logModifiedResources}

if ((Test-Path -Path $logModifiedResourceGroups) -eq $false)    {New-Item $logModifiedResourceGroups}

if ((Test-Path -Path $logResourceTagErrorsFile) -eq $false)    {New-Item $logResourceTagErrorsFile}

if ((Test-Path -Path $logResourceGroupTagErrorsFile) -eq $false)    {New-Item $logResourceGroupTagErrorsFile}

if ((Test-Path -Path $logUpdateTags) -eq $false) {
    New-Item $logUpdateTags
    Add-Content -Value "Log File $($logUpdateTags) - UpdateTags.ps1" -Path $logUpdateTags
    $dateToday = Get-Date -Format "yyyy/MM/dd - HH:mm:ss"
    $timestamp = Get-Date -Format o
    Add-Content -Value "[$($timestamp)] Log created: $($dateToday)" -Path $logUpdateTags
}


# Functions

function Write-Log {
    param (
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][switch]$OnlyLog)
    
    if (!$OnlyLog) {
        Write-Verbose -Message $Message
    }
    $dateToday = (Get-Date).ToUniversalTime() | Get-Date -Format o
    $Message = "[" + $dateToday + " UTC] " + $Message
    Add-Content -Value $Message -Path $logUpdateTags
}

function Wait-ForAnyKey {
    Write-Host -ForegroundColor Green "Press any key to continue..."
    $VerbosePreference = "SilentlyContinue"
    $response = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Log -Message "User Input - Wait-ForAnyKey: $($response.VirtualKeyCode)" -OnlyLog
    $VerbosePreference = "Continue"
}


# Set preferences
$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"


# Import Modules
Import-Module -Name Az.Accounts                             # Connect to Azure cmdlets
Import-Module -Name Az.Resources                            # Tag cmdlets
Import-Module -Name Microsoft.PowerShell.ConsoleGuiTools    # Console User Interface tools (Out-ConsoleGridView) cmdlets


# Rollback preferences
$VerbosePreference = "Continue"


# --- Start ---
# Connect to Azure
# Add different Connection options
try {
    Connect-AzAccount
    }

catch {
    Write-Log -Message "Error connecting to Azure" -OnlyLog
    Write-Log $_.Exception.message -OnlyLog
    Write-Output "Error connecting to Azure"
    Write-Output $_.Exception.message
    }


# Fetch all avaiable subscriptions and allow user selection(s) for tag search
Write-Log -Message "Getting list of Subscriptions"

$VerbosePreference = "SilentlyContinue"
$subscriptions = Get-AzSubscription | Out-ConsoleGridView -Title "Select Subscriptions to search for Tags" 
$VerbosePreference = "Continue"


# Cycle through all Azure subscriptions and display all tag names.
try {
    foreach ($subscription in $subscriptions) {
        # Set Context to subscription
        Write-Log -Message "Searching in Subscription: $($subscription.Name) - ID: ($($subscription.id)) "
        Set-AzContext -Subscription $subscription.Id | Format-List
                
        # Collect all tags within the selected subscriptions
        $AllTags += @(Get-Aztag)         
    }  
}

catch {
    # Catch anything that went wrong
    Write-Log -Message $_.Exception -OnlyLog
    Write-Error -Message $_.Exception
    throw $_.Exception
}


# Display list of queried subscriptions
Write-Log -Message "List of queried Subscriptions"
$subscriptions | Format-Table
Wait-ForAnyKey


# User selects which tags to update 
Write-Log -Message "All available Tags"
$VerbosePreference = "SilentlyContinue"
$SelectedTags = $AllTags | Out-ConsoleGridView -Title "Select Tags to Update"
$VerbosePreference = "Continue"


# User enters the new Key Name
Write-Verbose -Message "Type in the new Key name to replace the selected tags"
Write-Host -ForegroundColor Green "New Tag Key Name: " -NoNewline 
$newKeyName = read-host         # New Key Name that will replace all selected tag key names
Write-Host
Write-Log -Message "User input. Replacement Tag Key Name: '$($newKeyName)'" -OnlyLog
Write-Log -Message "'$($newKeyName)' will replace all selected Tag Key Names. Tag Values will remain unchanged."

    
# Confirmation messages before taking any modifying action
Write-Log -Message "List of selected Tags that will be updated and the number of resources & resource groups impacted"
$SelectedTags | Format-Table
Write-Log -Message "A total of '$($selectedTags.count)' tag variations are selected"
foreach ($selectedTag in $selectedTags) {$modifiedResourcesCount += $selectedTag.count}         # Count all resources and RG impacted
Write-Log -Message "A total of '$($modifiedResourcesCount)' Resources and Resource Groups were found with the selected tags"
Write-Host -ForegroundColor Red "WARNING: Please select [Y] to proceed and modify the Tags for the selected Resources and Resource Groups"
$confirmation = read-host


# Final confirmation before taking action
if ($confirmation -ne 'y') {
    Write-Host -ForegroundColor Green "No changes were made. Exiting script. Goodbye"
    Write-Log -Message "User Cancellation. No changes were made. Exiting script. Goodbye" -OnlyLog
    Exit
}
Write-Log -Message "...proceeding to modify resource tags"


# Find all resources with the selected tags in all selected subscriptions
$selectedResources = $null
$selectedResourceGroups = @()

foreach ($subscription in $subscriptions) {
    Set-AzContext -Subscription $subscription.Id
    Write-Log -Message "Setting AzContext to '$($subscription.Name)' - ID: '($($subscription.id))'" -OnlyLog

    foreach ($selectedTag in $selectedTags) {
        $selectedResources += Get-AzResource -TagName $selectedTag.Name
        $selectedResourceGroups += Get-AzResourceGroup -Tag @{$selectedTag.Name=$null}
    }   
}


# Export all Resources found with any of the selected Tags to CSV log file
Write-Log -Message "Search for all Resources with selected Tags completed." -OnlyLog
$selectedResources | Export-Csv -Path $logModifiedResources
Write-Log -Message "List of tagged Resources in CSV format created at: $($logModifiedResources)" -OnlyLog


# Export all Resources Groups found with any of the selected Tags to CSV log file
Write-Log -Message "Search for all ResourceGroups with selected Tags completed." -OnlyLog
$selectedResourceGroups | Export-Csv -Path $logModifiedResourceGroups
Write-Log -Message "List of tagged ResourceGroups in CSV format created at: $($logModifiedResourceGroups)" -OnlyLog


# Prepare to catch any errors and continue
$ErrorActionPreference = "Continue" 

$logResourceTagErrors = $null
$logResourceGroupTagErrors = $null

# Modify the tags for each of the Resources found
foreach ($selectedResource in $selectedResources) {
    
    Write-Log -Message "Searching for Tags in Resource: '$($selectedResource.Name)' - ResourceID: '$($selectedResource.Id)'" -OnlyLog

    # Prepraring hashtables
    $tagsNotFound = $null
    
    # Replace old tag with new tag keyname and value
    foreach ($selectedTag in $selectedTags) {
        
        $oldTag = $null
        $newTag = $null
        
        $oldSelectedTagValue = $null
        $oldSelectedTagValue = $selectedResource.Tags.($selectedTag.Name)

        if ($selectedResource.Tags.($selectedTag.Name) -or $selectedResource.Tags.($selectedTag.Name) -eq "") {
            $oldTag = @{[string]$selectedTag.Name = [string]$($oldSelectedTagValue);}
            $newTag = @{[string]$newKeyName = [string]$oldSelectedTagValue;}
            
            try {
                Update-AzTag -ResourceId $selectedResource.Id -Tag $newTag -Operation Merge
                Write-Log -Message "'$($newKeyName)' tag with tag value: '$($oldSelectedTagValue)' appended to ResourceID: '$($selectedResource.Id)'" -OnlyLog
            }
            catch {
                Write-Log -Message "[ERROR] '$($newKeyName)' tag with tag value: '$($oldSelectedTagValue)' could not be appended to ResourceID: '$($selectedResource.Id)'"
                $errorMessage = $_
                Write-Log -Message "[ERROR] $($errorMessage)"
                $logResourceTagErrors += $selectedResource
                Write-Verbose -Message "Error Logged. Proceeding to next Resource..."
            }
            
            try {
                Update-AzTag -ResourceId $selectedResource.Id -Tag $oldTag -Operation Delete
                Write-Log -Message "'$($selectedTag.Name)' tag with tag value: '$($oldSelectedTagValue)' removed from ResourceID: '$($selectedResource.Id)'" -OnlyLog
            }
            catch {
                Write-Log -Message "[ERROR] '$($newKeyName)' tag with tag value: '$($oldSelectedTagValue)' could not be removed from ResourceID: '$($selectedResource.Id)'"
                $errorMessage = $_
                Write-Log -Message "[ERROR] $($errorMessage)"
                $logResourceTagErrors += $selectedResource
                Write-Verbose -Message "Error Logged. Proceeding to next Resource..."
            }
            
        }
        else {
            if (!$tagsNotFound) {
                $tagsNotFound += $selectedTag.Name
            }
            else {
                $tagsNotFound += ", " + $selectedTag.Name
            }
        }
    }
    Write-Log -Message "Tags not found in this Resource: '$($tagsNotFound)'" -OnlyLog
}


# Modify the tags for each of the Resource Groups found
foreach ($selectedResourceGroup in $selectedResourceGroups) {
    
    Write-Log -Message "Searching for Tags in ResourceGroup: '$($selectedResourceGroup.ResourceGroupName)' - ResourceID: '$($selectedResourceGroup.ResourceId)'" -OnlyLog

    # Prepraring hashtables

    $tagsNotFound = $null
    
    # Replace old tag with new tag keyname and value
    foreach ($selectedTag in $selectedTags) {
        
        $oldTag = $null
        $newTag = $null
        
        $oldSelectedTagValue = $null
        $oldSelectedTagValue = $selectedResourceGroup.Tags.($selectedTag.Name)

        if ($selectedResourceGroup.Tags.($selectedTag.Name) -or $selectedResourceGroup.Tags.($selectedTag.Name) -eq "") {
            $oldTag = @{[string]$selectedTag.Name = [string]$oldSelectedTagValue;}
            $newTag = @{[string]$newKeyName = [string]$oldSelectedTagValue;}
            
            try {
                Update-AzTag -ResourceId $selectedResourceGroup.Id -Tag $newTag -Operation Merge
                Write-Log -Message "'$($newKeyName)' tag with tag value: '$($oldSelectedTagValue)' appended to ResourceGroupID: '$($selectedResourceGroup.Id)'" -OnlyLog
            }
            catch {
                Write-Log -Message "[ERROR] '$($newKeyName)' tag with tag value: '$($oldSelectedTagValue)' could not be appended to ResourceGroupID: '$($selectedResourceGroup.Id)'"
                $errorMessage = $_
                Write-Log -Message "[ERROR] $($errorMessage)"
                $logResourceGroupTagErrors += $selectedResourceGroup
                Write-Verbose -Message "Error Logged. Proceeding to next Resource Group..."
            }

            try {
                Update-AzTag -ResourceId $selectedResourceGroup.Id -Tag $oldTag -Operation Delete
                Write-Log -Message "'$($selectedTag.Name)' tag with tag value: '$($oldSelectedTagValue)' removed from ResourceGroupID: '$($selectedResourceGroup.Id)'" -OnlyLog
            }
            catch {
                Write-Log -Message "[ERROR] '$($newKeyName)' tag with tag value: '$($oldSelectedTagValue)' could not be removed from ResourceGroupID: '$($selectedResourceGroup.Id)'"
                $errorMessage = $_
                Write-Log -Message "[ERROR] $($errorMessage)"
                $logResourceGroupTagErrors += $selectedResourceGroup
                Write-Verbose -Message "Error Logged. Proceeding to next Resource..."
            }            
        }
        else {
            if (!$tagsNotFound) {
                $tagsNotFound += $selectedTag.Name
            }
            else {
                $tagsNotFound += ", " + $selectedTag.Name
            }
        }
    }
    Write-Log -Message "Tags not found in this Resource Group: '$($tagsNotFound)'" -OnlyLog
}

# Save all errors found
Write-Log -Message "List of Azure Resources with Tagging errors: $($logFilePath)UpdateTags-ResourceTagErrors$($logCreationTime).csv"
$logResourceTagErrors | Export-Csv -Path $logResourceTagErrorsFile

Write-Log -Message "List of modified Azure Resources with updated Tags: $($logFilePath)UpdateTags-ResourceGroupTagErrors$($logCreationTime).csv"
$logResourceGroupTagErrors | Export-Csv -Path $logResourceGroupTagErrorsFile


# Finalize
Write-Log -Message "Log File Created at: $($logFilePath)UpdateTags$($logCreationTime).log"
Write-Log -Message "List of modified Azure Resources with updated Tags: $($logFilePath)UpdateTags-ModifiedResources$($logCreationTime).csv"
Write-Log -Message "List of modified Azure Resource Groups with updated Tags: $($logFilePath)UpdateTags-ModifiedResourceGroups$($logCreationTime).csv"
Write-Log -Message "Operation Completed Successfully"
