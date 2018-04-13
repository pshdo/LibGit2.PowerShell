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

function Receive-GitCommit
{
    <#
    .SYNOPSIS
    Pulls or fetches remote changes for a repository

    .DESCRIPTION
    The `Recieve-GitCommit` function fetches or pulls the remote changes for the specified repository.

    If the -Fetch switch is used, all remotes are fetched. Otherwise, if the current branch can be fast-forwarded, the commits are pulled.

    It defaults to the current repository. Use the `RepoRoot` parameter to specify an explicit path to another repo.

    This function implements the `git fetch --all` and `git pull` commands.

    .EXAMPLE
    Receive-GitCommit -RepoRoot 'C:\Projects\GitAutomation'

    Demonstrates how to pull remotes changes for a repository that isn't the current directory.
    #>
    [CmdletBinding()]
    param(
        [string]
        # The repository to fetch updates for. Defaults to the current directory.
        $RepoRoot = (Get-Location).ProviderPath,

        [Switch]
        # Use this switch to only fetch updates, instead of pulling
        $Fetch
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $repo = Find-GitRepository -Path $RepoRoot -Verify
    if( -not $repo )
    {
        return
    }

    try
    {
        if( $Fetch )
        {
            foreach( $remote in $repo.Network.Remotes )
            {
                $repo.Network.Fetch($remote)
            } 
        }
        else
        {
            $pullOptions = New-Object LibGit2Sharp.PullOptions
            $mergeOptions = New-Object LibGit2Sharp.MergeOptions
            $mergeOptions.FastForwardStrategy = [LibGit2Sharp.FastForwardStrategy]::FastForwardOnly
            $pullOptions.MergeOptions = $mergeOptions
            $signature = $repo.Config.BuildSignature((Get-Date))
            [LibGit2Sharp.Commands]::Pull($repo, $signature, $pullOptions)
        }
    }
    finally
    {
        $repo.Dispose()
    }

}