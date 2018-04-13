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

Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-GitAutomationTest.ps1' -Resolve)

function GivenRemoteRepository
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )
    
    $script:remoteRepoPath = (Join-Path -Path $TestDrive -ChildPath $Path)
    New-GitRepository -Path $remoteRepoPath | Out-Null
    Add-GitTestFile -RepoRoot $remoteRepoPath -Path 'InitialCommit.txt'
    Add-GitItem -RepoRoot $remoteRepoPath -Path 'InitialCommit.txt'
    Save-GitChange -RepoRoot $remoteRepoPath -Message 'Initial Commit'
    Set-GitConfiguration -Name 'core.bare' -Value 'true' -RepoRoot $remoteRepoPath
}

function GivenLocalRepositoryTracksRemote
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )
    
    $script:localRepoPath = (Join-Path -Path $TestDrive -ChildPath $Path)
    Copy-GitRepository -Source $remoteRepoPath -DestinationPath $localRepoPath
}

function GivenLocalRepositoryWithNoRemote
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )
    
    $script:localRepoPath = (Join-Path -Path $TestDrive -ChildPath $Path)
    New-GitRepository -Path $localRepoPath | Out-Null
}

function GivenTag
{
    param(
        $Name
    )

    New-GitTag -RepoRoot $localRepoPath -Name $Name -Force
}

function GivenCommit
{
    $fileName = [IO.Path]::GetRandomFileName()
    Add-GitTestFile -RepoRoot $localRepoPath -Path $fileName | Out-Null
    Add-GitItem -RepoRoot $localRepoPath -Path $fileName
    Save-GitChange -RepoRoot $localRepoPath -Message $fileName
}

function GivenRemoteContainsOtherChanges
{
    Set-GitConfiguration -Name 'core.bare' -Value 'false' -RepoRoot $remoteRepoPath
    Add-GitTestFile -RepoRoot $remoteRepoPath -Path 'RemoteTestFile.txt'
    Add-GitItem -RepoRoot $remoteRepoPath -Path 'RemoteTestFile.txt'
    Save-GitChange -RepoRoot $remoteRepoPath -Message 'Adding remote test file to remote repo'
    Set-GitConfiguration -Name 'core.bare' -Value 'true' -RepoRoot $remoteRepoPath
}

function ThenNoErrorsWereThrown
{
    It 'should not throw any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

function ThenErrorWasThrown
{
    param(
        [string]
        $ErrorMessage
    )

    It ('should throw an error: ''{0}''' -f $ErrorMessage) {
        $Global:Error | Should -Match $ErrorMessage
    }
}

function ThenRemoteContainsLocalCommits
{
    It 'local repository should not have any unstaged changes' {
        Test-GitUncommittedChange -RepoRoot $localRepoPath | Should -BeFalse
    }
    
    It 'local repository should not have any outgoing commits' {
        Test-GitOutgoingCommit -RepoRoot $localRepoPath | Should -BeFalse
    }

    It 'the HEAD commit of the local repository should match the remote repository' {
        (Get-GitCommit -RepoRoot $remoteRepoPath -Revision HEAD).Sha | Should -Be (Get-GitCommit -RepoRoot $localRepoPath -Revision HEAD).Sha
    }
}

function ThenRemoteRevision
{
    param(
        [Parameter(Position=0)]
        $Revision,

        [Switch]
        $Exists,

        [Switch]
        $DoesNotExist,

        $HasSha
    )

    $commitExists = Test-GitCommit -RepoRoot $remoteRepoPath -Revision $Revision 
    if( $Exists )
    {
        It ('should push refspec to remote') {
            $commitExists | Should -BeTrue
            if( $HasSha )
            {
                $commit = Get-GitCommit -RepoRoot $remoteRepoPath -Revision $Revision
                $commit.Sha | Should -Be $HasSha
            }
        }
    }
    else
    {
        It ('should not push refspec to remote') {
            $commitExists | Should -Be $false
        }
    }
}

function ThenPushResultIs
{
    param(
        $PushStatus
    )

    It ('function returned status of ''{0}''' -f $script:pushResult) {
        $script:pushResult | Should -Be $PushStatus
    }
}

function WhenSendingObject
{
    [CmdletBinding()]
    param(
        $RefSpec,
        [Switch]
        $Tags
    )

    $Global:Error.Clear()
    $script:pushResult = $null

    $params = @{
                    RefSpec = $RefSpec
                }
    if( $Tags )
    {
        $params = @{
                        Tags = $true
                    }
    }
    
    $script:pushResult = Send-GitObject -RepoRoot $localRepoPath @params
}

Describe 'Send-GitObject.when pushing changes to a remote repository' {
    GivenRemoteRepository 'RemoteRepo'
    GivenLocalRepositoryTracksRemote 'LocalRepo'
    GivenCommit
    WhenSendingObject 'refs/heads/master'
    ThenNoErrorsWereThrown
    ThenPushResultIs ([Git.Automation.PushResult]::Ok)
    ThenRemoteContainsLocalCommits
}

Describe 'Send-GitObject.when there are no local changes to push to remote' {
    GivenRemoteRepository 'RemoteRepo'
    GivenLocalRepositoryTracksRemote 'LocalRepo'
    WhenSendingObject 'refs/heads/master'
    ThenNoErrorsWereThrown
    ThenPushResultIs ([Git.Automation.PushResult]::Ok)
}

Describe 'Send-GitObject.when remote repository has changes not contained locally' {
    GivenRemoteRepository 'RemoteRepo'
    GivenLocalRepositoryTracksRemote 'LocalRepo'
    GivenRemoteContainsOtherChanges
    GivenCommit
    WhenSendingObject 'refs/heads/master' -ErrorAction SilentlyContinue
    ThenErrorWasThrown 'that you are trying to update on the remote contains commits that are not present locally.'
    ThenPushResultIs ([Git.Automation.PushResult]::Rejected)
}

Describe 'Send-GitObject.when no upstream remote is defined' {
    GivenLocalRepositoryWithNoRemote 'LocalRepo'
    GivenCommit
    WhenSendingObject 'refs/heads/master' -ErrorAction SilentlyContinue
    ThenErrorWasThrown 'A\ remote\ named\ "origin"\ does\ not\ exist\.'
    ThenPushResultIs ([Git.Automation.PushResult]::Failed)
}

Describe 'Send-GitObject.when refspec doesn''t exist' {
    GivenRemoteRepository 'RemoteRepo'
    GivenLocalRepositoryTracksRemote 'LocalRepo'
    WhenSendingObject 'refs/heads/dsfsdaf' -ErrorAction SilentlyContinue
    ThenErrorWasThrown 'does\ not\ match\ any\ existing\ object'
    ThenPushResultIs ([Git.Automation.PushResult]::Failed)
}

Describe 'Send-GitObject.when pushing tags' {
    GivenRemoteRepository 'RemoteRepo'
    GivenLocalRepositoryTracksRemote 'LocalRepo'
    GivenTag 'tag1'
    GivenTag 'tag2'
    WhenSendingObject 'refs/tags/tag1'
    ThenRemoteRevision 'tag1' -Exists
    ThenRemoteRevision 'tag2' -DoesNotExist
}

Describe 'Send-GitObject.when pushing all tags' {
    GivenRemoteRepository 'RemoteRepo'
    GivenLocalRepositoryTracksRemote 'LocalRepo'
    GivenTag 'tag1'
    GivenTag 'tag2'
    WhenSendingObject -Tags
    ThenRemoteRevision 'tag1' -Exists
    ThenRemoteRevision 'tag2' -Exists
}

Describe 'Send-GitObject.when tags moved' {
    GivenRemoteRepository 'RemoteRepo'
    GivenLocalRepositoryTracksRemote 'LocalRepo'
    GivenTag 'tag1'
    GivenTag 'tag2'
    WhenSendingObject -Tags
    ThenRemoteRevision 'tag1' -Exists
    ThenRemoteRevision 'tag2' -Exists
    $commit = GivenCommit
    GivenTag 'tag1'
    GivenTag 'tag2'
    WhenSendingObject 'refs/heads/master'
    WhenSendingObject -Tags
    ThenRemoteRevision 'tag1' -Exists -HasSha $commit.Sha
    ThenRemoteRevision 'tag2' -Exists -HasSha $commit.Sha
}