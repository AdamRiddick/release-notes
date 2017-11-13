[CmdletBinding()]
param (
    [parameter(Mandatory=$false,HelpMessage="The path to save a file with the release notes output.")]
    $outputfilePath,

    [parameter(Mandatory=$false,HelpMessage="The name of the release variable to save the release notes output to - This can be used later in your environment to output the release notes, for example, within an email task.")]
    $outputVariableName,

    [parameter(Mandatory=$false,HelpMessage="Name of the release environment to compare build artifacts in. If not provided, the environment housing this task is used.")]
    $releaseEnvironmentName,

    [parameter(Mandatory=$true,HelpMessage="Personal access token to use in calling TFS/Team Services API's to gather release notes.")]
    $personalAccessToken,

    [parameter(Mandatory=$false,HelpMessage="Release notes template.")]
    [String]$template = '<ul style="margin:0; padding:0;">{messages}<li style="margin:0 0 1em; list-style:disc inside; mso-special-format:bullet;">{message}</li>{messages}</ul>',

    [parameter(Mandatory=$false,HelpMessage="Replacement tag for changeset message.")]
    [String]$templateMessageVariable = '{message}',

    [parameter(Mandatory=$false,HelpMessage="Replacement tag to define template to use per message.")]
    [String]$templateMessagesVariable = '{message}'
)

Write-Host "Begin Creating Release Notes From Current Release"

#############################################################################################################################################
### Setup Variables
#############################################################################################################################################
# Environmental Variables are set by Team Services
$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$currentEnvironmentName = $env:RELEASE_ENVIRONMENTNAME
$currentReleaseId = $env:RELEASE_RELEASEID
$releaseDefinitionId = $env:RELEASE_DEFINITIONID
$teamProject = $env:SYSTEM_TEAMPROJECT

if(-not [String]::IsNullOrWhiteSpace($releaseEnvironmentName))
{
    $currentEnvironmentName = $releaseEnvironmentName
}

# Build authorization header to be shared among requests
$authorizationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)")) }

# Build base API URI
$baseApiUri = "$collectionUrl/$teamProject/_apis" 

#############################################################################################################################################
### Output Variables
#############################################################################################################################################
Write-Host "Base API Uri [$baseApiUri]"
Write-Host "Collection URL [$collectionUrl]"
Write-Host "Current Environment Name [$currentEnvironmentName]"
Write-Host "Current Release Id [$currentReleaseId]"
Write-Host "Output File Path [$outputFilePath]"
Write-Host "Output Variable Name [$outputVariableName]"
Write-Host "Personal Access Token [$personalAccessToken]"
Write-Host "Release Definition Id [$releaseDefinitionId]"
Write-Host "Team Project [$teamProject]"
Write-Host "Template [$template]"
Write-Host "Template Message Variable [$templateMessageVariable]"
Write-Host "Template Messages Variable [$templateMessagesVariable]"

#############################################################################################################################################
### Load Latest and Previous releases
#############################################################################################################################################
# Get the latest complete releases, so we can compare their build artifacts
$previewUrl = $baseApiUri -replace ".visualstudio.com",  ".vsrm.visualstudio.com/defaultcollection" #Preview requires vsrm in the URL, this is temp.
$releaseUri = "$($previewUrl)release/releases?definitionId=$releaseDefinitionId&`$Expand=environments,artifacts&queryOrder=descending&api-version=4.1-preview"
Write-Host "Invoking release endpoint to find latest complete releases [$releaseUri]"
$allReleases = Invoke-RestMethod -ContentType "application/json" -Method Get -Uri $releaseUri -Headers $authorizationHeader

# Get the current release - the one execuring this task
$currentRelease = $allReleases.value[0]
Write-Host "Current release is release id [$($currentRelease.id)]"

# Get the previous release to have completed the current environment successfully
# Assumes the releases are ordered by date, descending
foreach ($release in $allReleases.value | Where-Object { $_.id -ne $currentReleaseId })
{
    $environment = $release.environments | Where-Object { $_.name -eq $currentEnvironmentName -and $_.status -eq "succeeded" }
    if ($environment -ne $null)
    {
        Write-Host "Last release to successfully execute environment [$currentEnvironmentName] is release id [$($release.id)]"
        $previousRelease = $release
        break
    }     
}

#############################################################################################################################################
### Get Changes Between Builds
#############################################################################################################################################
$messages = @() # To hold changeset / commit messages

# Compare the builds for every artifact in the release
foreach ($currentReleaseArtifact in $currentRelease.artifacts)
{
    Write-Host "Discovering changes to artifact [$($currentReleaseArtifact.Alias)]"

    # Find the same artifact in the previous release
    $previousReleaseArtifact = $previousRelease.artifacts | Where-Object { $_.definitionReference.sourceId -eq $currentRelease.definitionReference.sourceId }
    
    # Build Id of the artifact in the current release
    $toBuildId = $currentReleaseArtifact.definitionReference.version.id
    $toBuildName = $currentReleaseArtifact.definitionReference.version.name

    $changesBetweenBuildsUri = "$baseApiUri/build/changes?toBuildId=$toBuildId&api-version=4.1-preview"

    if ($previousReleaseArtifact -eq $null)
    {
        Write-Host "No previous artifact found, unable to continue as TFS/Team Services API only supports changes between builds."
        exit
    }
    else 
    {
        $fromBuildId = $previousReleaseArtifact.definitionReference.version.id
        $fromBuildName = $previousReleaseArtifact.definitionReference.version.name

        Write-Host "Previous artifact found, discovering all changes between [$fromBuildName](ID:[$fromBuildId]) and [$toBuildName](ID:[$toBuildId])"

        $changesBetweenBuildsUri = "$changesBetweenBuildsUri&fromBuildId=$fromBuildId"
    }

    Write-Host "Invoking [$changesBetweenBuildsUri]"
    $changes = Invoke-RestMethod -ContentType "application/json" -Method Get -Uri $changesBetweenBuildsUri -Headers $authorizationHeader

    # Extract template parts, message template is between {message} tags
    $pattern = "$templateMessagesVariable(.*?)$templateMessagesVariable"
    $messageTemplate = [regex]::Match($template,$pattern).Groups[1].Value
    $messagesTemplate = "$templateMessagesVariable$messageTemplate$templateMessagesVariable"

    foreach ($changeMessage in $changes.value)
    {
        # Commit messages include the description, but are truncated. Only take up to the first newline.
        $message = $changeMessage.message.Split([Environment]::NewLine)[0]

        # Ensure the message ends with a full stop.
        if (-Not $message.EndsWith('.'))
        {
            $message += '.'
        }

        # Apply the message template to the output message
        $outputMessage = $messageTemplate -replace $templateMessageVariable, $message

        Write-Host "Adding change message [$outputMessage]"
        $messages += $outputMessage
    }
}

#############################################################################################################################################
### Generate Output
#############################################################################################################################################
Write-Host "Compiling change messages into output"
$generatedOutputMessageTemplate = $messages -join [Environment]::NewLine
$output = $template -replace $messagesTemplate, $generatedOutputMessageTemplate
Write-Host "Generated Release Note Output"

# If we have an output variable name, save to it
if(-not [String]::IsNullOrWhiteSpace($outputVariableName))
{
    Write-Host "Assigning output to variable [$outputVariableName]"
    Write-Host "##vso[task.setvariable variable=$outputVariableName]$output"
}

# If we have an output filepath, save to it
if(-not [String]::IsNullOrWhiteSpace($outputfilePath))
{
    Write-Host "Saving generated output to file [$outputFilePath]"
    Set-Content $outputFilePath $output
}

Write-Host "Release Note Creation Complete"