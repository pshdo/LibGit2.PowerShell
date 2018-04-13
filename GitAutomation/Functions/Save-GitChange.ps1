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

function Save-GitChange
{
    <#
    .SYNOPSIS
    Commits changes to a Git repository.

    .DESCRIPTION
    The `Save-GitChange` function commits changes to a Git repository. Those changes must be staged first with `git add` or the `GitAutomation` module's `Add-GitItem` function. If there are no changes staged, nothing happens, and nothing is returned.

    You are required to pass a commit message with the `Message` parameter. This module is intended to be used by non-interactive repository automation scripts, so opening in an editor is not supported.

    Implements the `git commit` command.

    .OUTPUTS
    Git.Automation.CommitInfo

    .LINK
    Add-GitItem

    .EXAMPLE
    Save-GitChange -Message 'Creating Save-GitChange function.'

    Demonstrates how to commit staged changes in a Git repository. In this example, the repository is assumed to be in the current directory.

    .EXAMPLE
    Save-GitChange -Message 'Creating Save-GitChange function.' -RepoRoot 'C:\Projects\GitAutomation'

    Demonstrates how to commit changes to a repository other than the current directory.

    .EXAMPLE
    Save-GitChange -Message 'Creating Save-GitChange function.' -Signature (New-GitSignature -Name 'Name' -EmailAddress 'email@example.com')

    Demonstrates how to set custom author metadata. In this case, the commit will be from user "Name" whose email address is "email@example.com".
    #>
    [CmdletBinding()]
    [OutputType([Git.Automation.CommitInfo])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The commit message.
        $Message,

        [string]
        # The repository where to commit staged changes. Defaults to the current directory.
        $RepoRoot = (Get-Location).ProviderPath,

        [LibGit2Sharp.Signature]
        # Author metadata. If not provided, it is pulled from configuration. To create an author/signature object, 
        #
        #     New-GitSignature -name 'Name' -EmailAddress 'email@example.com'
        #
        $Signature
    )

    Set-StrictMode -Version 'Latest'

    $repo = Find-GitRepository -Path $RepoRoot -Verify
    if( -not $repo )
    {
        return
    }

    try
    {
        $commitOptions = New-Object 'LibGit2Sharp.CommitOptions'
        $commitOptions.AllowEmptyCommit = $false
        if( -not $Signature )
        {
            $Signature = New-GitSignature -RepoRoot $RepoRoot -ErrorAction Ignore
            if( -not $Signature )
            {
                Write-Error -Message ('Failed to build author signature from Git configuration files. Pass an author signature to the "Signature" parameter (use the "New-GitSignature" function to create an author signature) or set author information in Git''s user-level configuration files by running these commands:
 
    git config --global user.name "GIVEN_NAME SURNAME"
    git config --global user.email "email@example.com"
 ')
                return
            }
        }

        $repo.Commit( $Message, $Signature, $Signature, $commitOptions ) |
            ForEach-Object { New-Object 'Git.Automation.CommitInfo' $_ } 
    }
    catch [LibGit2Sharp.EmptyCommitException]
    {
        Write-Warning -Message ('Nothing to commit. Git only commits changes that are staged. To stage changes, use the Add-GitItem function or the `git add` command.')
    }
    catch 
    {
        Write-Error -ErrorRecord $_
    }
    finally
    {
        $repo.Dispose()
    }

}