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

function Merge-GitCommit
{
    <#
    .SYNOPSIS
    Merges a commit into the current branch.

    .DESCRIPTION
    The `Merge-GitCommit` function merges a commit into the current branch. The commit can be identified with its ID, by a tag name, or branch name. It returns a `Git.Automation.MergeResult` object, which has two properties:

    * `Status`: the status of the merge. It will be one of the following values:
      * `Conflicts`: when there are conflicts with the merge.
      * `FastForward`: when the merge resulted in a fast-forward.
      * `NonFastForward`: when a merge commit was created.
      * `UpToDate`: when nothing needed to be merged.
    * `Commit`: the merge commit (if one was created).

    If there are conflicts, the conflicts are left in place. You can use your preferred merge tool to resolve the conflicts and then commit. If this script is running non-interactively, you probably don't want any conflict markers hanging out in your local files. Use the "-NonInteractive" switch to prevent conflict files from remaining.

    By default, the function operates on the Git repository in the current directory. Use the `RepoRoot` parameter to target a different repository.

    .EXAMPLE
    Merge-GitCommit -Revision 'develop'

    Demonstrates how to merge a branch into the current branch.
    #>
    [CmdletBinding()]
    [OutputType([Git.Automation.MergeResult])]
    param(
        [string]
        # The path to the repository where the files should be added. The default is the current directory as returned by Get-Location.
        $RepoRoot = (Get-Location).ProviderPath,

        [Parameter(Mandatory=$true)]
        [string]
        # The revision to merge into the current commit (i.e. HEAD). A revision can be a specific commit ID/sha (short or long), branch name, tag name, etc. Run git help gitrevisions or go to https://git-scm.com/docs/gitrevisions for full documentation on Git's revision syntax.
        $Revision = "HEAD",

        [string]
        [ValidateSet('No','Only')]
        # Controls whether or not to do a fast-forward merge. By default, "Merge-GitCommit" will try to do a fast-forward merge if it can. If it can't it will create a new merge commit. Options are:
        # 
        # * `No`: Don't do a fast-forward merge. Always create a merge commit.
        # * `Only`: Only do a fast-forward merge. No new merge commit is created.
        $FastForward,

        [Switch]
        # The merge is happening non-interactively. If there are any conflicts, the working directory will be left in the state it was in before the merge, i.e. there will be no conflict markers left in any files.
        $NonInteractive
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $repo = Get-GitRepository -RepoRoot $RepoRoot
    if( -not $repo )
    {
        return
    }

    [LibGit2Sharp.MergeOptions]$mergeOptions = New-Object -TypeName 'LibGit2Sharp.MergeOptions'
    $mergeOptions.CommitOnSuccess = $true
    $mergeOptions.FailOnConflict = $false
    if( $NonInteractive )
    {
        $mergeOptions.FailOnConflict = $true
    }
    $mergeOptions.FindRenames = $true
    if( $FastForward -eq 'No' )
    {
        $mergeOptions.FastForwardStrategy = [LibGit2Sharp.FastForwardStrategy]::NoFastForward
    }
    elseif( $FastForward -eq 'Only' )
    {
        $mergeOptions.FastForwardStrategy = [LibGit2Sharp.FastForwardStrategy]::FastForwardOnly
    }

    $signature = $repo.Config.BuildSignature((Get-Date))
    try
    {
        $result = $repo.Merge($Revision,$signature,$mergeOptions)
        New-Object -TypeName 'Git.Automation.MergeResult' -ArgumentList $result
    }
    catch
    {
        Write-Error -Exception $_.Exception
    }
    finally
    {
        $repo.Dispose()
    }
}