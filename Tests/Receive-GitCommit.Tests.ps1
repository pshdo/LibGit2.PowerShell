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

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-GitAutomationTest.ps1' -Resolve)

Describe 'Receive-GitCommit with the -Pull switch when there are incoming commits on master'{
    Clear-Error

    $remoteRepo = New-GitTestRepo
    Add-GitTestFile -RepoRoot $remoteRepo -Path 'file1'
    Add-GitItem -Path (Join-Path -Path $remoteRepo -ChildPath 'file1') -RepoRoot $remoteRepo
    Save-GitChange -RepoRoot $remoteRepo -Message 'file1 commit'

    $localRepoPath = Join-Path -Path (Resolve-TestDrivePath) -ChildPath 'LocalRepo'
    Copy-GitRepository -Source $remoteRepo -DestinationPath $localRepoPath

    Add-GitTestFile -RepoRoot $remoteRepo -Path 'file2'
    Add-GitItem -Path (Join-Path -Path $remoteRepo -ChildPath 'file2') -RepoRoot $remoteRepo
    Save-GitChange -RepoRoot $remoteRepo -Message 'file2 commit'

    $repo = Find-GitRepository -Path $localRepoPath
    $remote = Find-GitRepository -Path $remoteRepo
    try{
        $repo.Head.Tip.Sha | Should Not Be $remote.Head.Tip.Sha
        Receive-GitCommit -RepoRoot $localRepoPath

        It 'should fast-forward remote changes on master'{        
            $repo.Head.Tip.Sha | Should Be $remote.Head.Tip.Sha
        }

    }
    finally{
        $repo.Dispose()
        $remote.Dispose()
    }
   
    Assert-ThereAreNoErrors
}

Describe 'Receive-GitCommit when ran withouth the -Pull switch'{
    Clear-Error

    $remoteRepo = New-GitTestRepo
    Add-GitTestFile -RepoRoot $remoteRepo -Path 'file1'
    Add-GitItem -Path (Join-Path -Path $remoteRepo -ChildPath 'file1') -RepoRoot $remoteRepo
    Save-GitChange -RepoRoot $remoteRepo -Message 'file1 commit'

    $localRepoPath = Join-Path -Path (Resolve-TestDrivePath) -ChildPath 'LocalRepo'
    Copy-GitRepository -Source $remoteRepo -DestinationPath $localRepoPath

    Add-GitTestFile -RepoRoot $remoteRepo -Path 'file2'
    Add-GitItem -Path (Join-Path -Path $remoteRepo -ChildPath 'file2') -RepoRoot $remoteRepo
    Save-GitChange -RepoRoot $remoteRepo -Message 'file2 commit'

    $repo = Find-GitRepository -Path $localRepoPath
    $remote = Find-GitRepository -Path $remoteRepo
    try{
        $repo.Head.Tip.Sha | Should Not Be $remote.Head.Tip.Sha
        Receive-GitCommit -RepoRoot $localRepoPath -Fetch

        It 'should fetch commits for tracked local branches'{
            Test-GitIncomingCommit -RepoRoot $localRepoPath | Should Be $true
        }

        It 'should not merge remote changes'{        
            $repo.Head.Tip.Sha | Should Not Be $remote.Head.Tip.Sha
        }

    }
    finally{
        $repo.Dispose()
        $remote.Dispose()
    }
   
    Assert-ThereAreNoErrors
}

Describe 'Receive-GitChange when the given repo doesn''t exist' {
    Clear-Error

    Receive-GitCommit -RepoRoot 'C:\I\do\not\exist' -ErrorAction SilentlyContinue
    It 'should write an error' {
        $Global:Error.Count | Should Be 1
        $Global:Error | Should Match 'does not exist'
    }
}