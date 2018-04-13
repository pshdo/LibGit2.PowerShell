# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Add-GitTestFile
{
    [CmdletBinding()]
    param(
        [string]
        $RepoRoot,

        [string[]]
        $Path
    )

    Push-Location $RepoRoot
    try
    {
        foreach( $filePath in $Path )
        {
            if( (Test-Path -Path $filePath -PathType Leaf) )
            {
                continue
            }

            New-Item -Path $filePath -ItemType 'File' -Force
            [Guid]::NewGuid() | Set-Content -Path $filePath
        }
    }
    finally
    {
        Pop-Location
    }
}

function Assert-ThereAreNoErrors
{
    It 'should write no errors' {
        $Global:Error.Count | Should Be 0
    }
}

function Clear-Error
{
    $Global:Error.Clear()
}

function New-GitTestRepo
{
    param(
    )

    $testDrive = (Get-Item -Path 'TestDrive:').FullName
    $repoRoot = Join-Path -Path $testDrive -ChildPath ('GitAutomation.{0}' -f ([IO.Path]::GetRandomFileName()))
    New-GitRepository -Path $repoRoot | Format-List | Out-String | Write-Debug
    return $repoRoot
}

function Resolve-TestDrivePath
{
    return (Get-Item -Path 'TestDrive:').FullName
}