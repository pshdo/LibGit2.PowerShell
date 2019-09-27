
function Sync-GitBranch
{
    <#
    .SYNOPSIS
    Updates the current branch so it is in sync with its remote branch.

    .DESCRIPTION
    The `Sync-GitBranch` function merges in commits from the current branch's remote branch. It pulls in these commits from the remote repository. If there are new commits in the remote branch, they are merged into your current branch and a new commit is created. If there are no new commits in the remote branch, the remote branch is updated to point to the head of your current branch. This is called a "fast forward" merge. 
    
    This function's default behavior is controlled by Git's `merge.ff` setting. If unset or set to `true`, it behaves as described above. You can also use the `MergeStrategy` parameter to control how you want remote commits to get merged into your branch.
    
    If the `merge.ff` setting is `only`, or you pass `FastForward` to the `MergeStrategy` parameter, this function will only do a fast-forward merge. If there are new commits in the remote branch, a fast-forward merge is impossible and this function will fail.
    
    If the `merge.ff` setting is `false`, or you pass `Merge` to the `MergeStrategy` parameter, the function will always create a merge commit, even if there are no new commits on the remote branch. 

    Returns a `LibGit2Sharp.MergeResult` object, which has two properties:
    
    * `Commit`: the merge commit created, if any.
    * `Status`: the status of the merge. One of:
        * `UpToDate`: there were no new changes on the remote branch to bring in. In this case, `Commit` will be empty.
        * `FastForward`: the merge was fast-forwarded. In this case, `Commit` will be emtpy.
        * `NonFastForward`: a new merge commit was created. In this case, `Commit` will be the commit object created`.
        * `Conflicts`: merging in the remote branch resulted in merge conflicts. You'll need to do extra processing to resolve the conflicts.

    If the function needs to create a merge commit, but the `merge.ff` option is `only` or the `MergeStrategy` parameter is `FastForward`, the function will write an error and return `$null`.

    If there are conflicts made during the merge, this function won't write an error. You need to check the return object to ensure there are no conflicts.

    If the current branch isn't tracking a remote branch, this function will look for a remote branch with the same name, and create tracking information. If there is no remote branch with the same name, this function will write an error and return `$null`.

    By default, this function works on the repository in the current directory. Use the `RepoRoot` parameter to specify an explicit repository.

    This function implements the `git pull` command.

    .EXAMPLE
    Sync-GitBranch

    Demonstrates the simplest way to get your current branch up-to-date with its remote branch. 

    .EXAMPLE
    Sync-GitBranch -RepoRoot 'C:\Projects\GitAutomation'

    Demonstrates how to pull remotes commits for a repository that isn't in the current directory.
    #>
    [CmdletBinding()]
    [OutputType([LibGit2Sharp.MergeResult])]
    param(
        [string]
        # The repository to fetch updates for. Defaults to the current directory.
        $RepoRoot = (Get-Location).ProviderPath,

        [ValidateSet('FastForward','Merge')]
        [string]
        # What to do when merging remote changes into your local branch. By default, will use your configured `merge.ff` configuration options. Set to `Merge` to always create a merge commit. Use `FastForward` to only allow fast-forward "merges" (i.e. move the remote branch to point to your local branch head if there are no new changes on the remote branch). When automating, the safest option is `Merge`. If you choose `FastForward` and the remote branch has new changes on it, this function will fail.
        $MergeStrategy
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
        $branch = $repo.Branches | Where-Object { $_.IsCurrentRepositoryHead }
        if( -not $branch )
        {
            Write-Error -Message ('Repository in "{0}" isn''t on a branch. Use "Update-GitRepository" to update to a branch.' -f $RepoRoot)
            return
        }

        if( -not $branch.IsTracking )
        {
            [LibGit2Sharp.Branch]$remoteBranch = $repo.Branches | Where-Object { $_.UpstreamBranchCanonicalName -eq $branch.CanonicalName }
            if( -not $remoteBranch )
            {
                Write-Error -Message ('Branch "{0}" in repository "{1}" isn''t tracking a remote branch and we''re unable to find a remote branch named "{0}".' -f $branch.FriendlyName,$RepoRoot)
                return
            }
        
            [void]$repo.Branches.Update($branch, {
                param(
                    [LibGit2Sharp.BranchUpdater]
                    $Updater
                )
        
                $Updater.TrackedBranch = $remoteBranch.CanonicalName
            })
        }

        $pullOptions = New-Object LibGit2Sharp.PullOptions
        $mergeOptions = New-Object LibGit2Sharp.MergeOptions
        $mergeOptions.FastForwardStrategy = [LibGit2Sharp.FastForwardStrategy]::Default
        if( $MergeStrategy -eq 'FastForward' )
        {
            $mergeOptions.FastForwardStrategy = [LibGit2Sharp.FastForwardStrategy]::FastForwardOnly
        }
        elseif( $MergeStrategy -eq 'Merge' )
        {
            $mergeOptions.FastForwardStrategy = [LibGit2Sharp.FastForwardStrategy]::NoFastForward
        }
        $pullOptions.MergeOptions = $mergeOptions
        $signature = New-GitSignature -RepoRoot $RepoRoot
        try
        {
            [LibGit2Sharp.Commands]::Pull($repo, $signature, $pullOptions)
        }
        catch
        {
            Write-Error -ErrorRecord $_
        }
    }
    finally
    {
        $repo.Dispose()
    }

}