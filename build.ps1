[CmdletBinding(DefaultParameterSetName='Build')]
param(
    [Parameter(Mandatory=$true,ParameterSetName='Clean')]
    [Switch]
    # Runs the build in clean mode, which removes any files, tools, packages created by previous builds.
    $Clean,

    [Parameter(Mandatory=$true,ParameterSetName='Initialize')]
    [Switch]
    # Initializes the repository.
    $Initialize
)


#Requires -Version 4
Set-StrictMode -Version Latest

& (Join-Path -Path $PSScriptRoot -ChildPath '.whiskey\Import-Whiskey.ps1' -Resolve)

$configPath = Join-Path -Path $PSScriptRoot -ChildPath 'whiskey.yml' -Resolve

$optionalArgs = @{ }
if( $Clean )
{
    $optionalArgs['Clean'] = $true
}

if( $Initialize )
{
    $optionalArgs['Initialize'] = $true
}

if( (Test-Path -Path 'env:APPVEYOR') )
{
    Get-ChildItem -Path 'env:' | 
        Where-Object { $_.Name -notlike '*API*' }
}

$context = New-WhiskeyContext -Environment 'Dev' -ConfigurationPath $configPath
if( (Test-Path -Path 'env:GITHUB_ACCESS_TOKEN') )
{
    Add-WhiskeyApiKey -Context $context -ID 'github.com' -Value $env:GITHUB_ACCESS_TOKEN
}
if( (Test-Path -Path 'env:POWERSHELLGALLERY_COM_API_KEY') )
{
    Add-WhiskeyApiKey -Context $context -ID 'powershellgallery.com' -Value $env:POWERSHELLGALLERY_COM_API_KEY
}
Invoke-WhiskeyBuild -Context $context @optionalArgs
