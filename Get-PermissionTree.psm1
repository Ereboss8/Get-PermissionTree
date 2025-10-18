# Start of Get-PermissionTree.psm1
function Get-PermissionTree {
    param(
        # User to check permissions for (Default: Current User)
        [string]$User = $env:USERNAME,
        # Depth for how deep the tree goes (Default: 1)
        [int]$Depth = 1,
        # Path to start from (Default: Current Path)
        [string]$Path = $PWD
    )

    # Check if the path exists
    if (-Not (Test-Path -Path $Path)) {
        Write-Error "The specified path '$Path' does not exist."
        return
    }

    # Check if the user exists
    if (-Not (Get-LocalUser -Name $User -ErrorAction SilentlyContinue)) {
        Write-Error "The specified user '$User' does not exist."
        return
    }

    # Get the full username format
    $fullUsername = "$env:COMPUTERNAME\$User"

    # Box-drawing glyphs as chars
    $g_t = [char]0x251C    # ├ T-junction
    $g_l = [char]0x2514    # └ L-corner
    $g_v = [char]0x2502    # │ Vertical line
    $g_h = [char]0x2500    # ─ Horizontal line

    # Recursively process directories and print permissions
    function Get-DirectoryTree {
        param(
            [string]$Path,
            [int]$Depth,
            [int]$CurrentDepth = 0,
            [string]$Indent = "",
            [bool]$IsLast = $false
        )

        # Determine display name
        if ($CurrentDepth -eq 0) {
            $displayName = $Path # Root uses full path
        }
        else {
            $displayName = Split-Path -Path $Path -Leaf # Children use leaf name
        }

        # Check if the user can access the directory
        try {
            $null = Get-ChildItem -Path $Path -ErrorAction Stop
        }
        catch {
            Write-Output ("$Indent" + $g_l + $g_h2 + " $displayName : [Access Denied]")
            return
        }

        # Get ACL for the current directory
        try {
            $acl = Get-Acl -Path $Path -ErrorAction Stop
        }
        catch {
            Write-Output ("$Indent" + $g_l + $g_h2 + " $displayName : [Access Denied]")
            return
        }

        # Build identity candidates to check for effective permissions
        $identityCandidates = @()
        $identityCandidates += $fullUsername
        $identityCandidates += $User

        # Try include local groups the user is a member of
        try {
            $localGroups = Get-LocalGroup -ErrorAction SilentlyContinue
            if ($localGroups) {
                foreach ($g in $localGroups) {
                    try {
                        $members = Get-LocalGroupMember -Group $g.Name -ErrorAction SilentlyContinue
                        if ($members) {
                            foreach ($m in $members) {
                                if (($m.Name -eq $fullUsername) -or ($m.Name -eq $User) -or ($m.Name -like "*\$User")) {
                                    $identityCandidates += ("$env:COMPUTERNAME\$($g.Name)")
                                    break
                                }
                            }
                        }
                    }
                    catch { }
                }
            }
        }
        catch { }

        # Match ACL entries to any of the identity candidates to derive effective permissions
        $matchedAces = @()
        foreach ($ace in $acl.Access) {
            $id = $ace.IdentityReference.Value
            if ($identityCandidates -contains $id -or $identityCandidates -contains $ace.IdentityReference.ToString()) {
                $matchedAces += $ace
            }
        }

        # If no ACE matched directly, fall back to substring username matching
        if ($matchedAces.Count -eq 0) {
            foreach ($ace in $acl.Access) {
                if ($ace.IdentityReference.Value -like "*$User") {
                    $matchedAces += $ace
                }
            }
        }

        # Aggregate allowed and denied rights separately
        $allowedRights = 0
        $deniedRights = 0
        foreach ($ace in $matchedAces) {
            try {
                $rights = [int]$ace.FileSystemRights
            }
            catch {
                $rights = 0
            }
            if ($ace.AccessControlType -eq 'Deny') {
                $deniedRights = $deniedRights -bor $rights
            }
            else {
                $allowedRights = $allowedRights -bor $rights
            }
        }

        # Remove denied bits from allowed bits to get effective rights
        $effectiveRights = $allowedRights -band (-bnot $deniedRights)

        # Simplify effective permissions to Read, Write, and Execute by inspecting effectiveRights
        $userPermissions = @()
        if ($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::Read) {
            $userPermissions += 'Read'
        }
        if ($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::Write) {
            $userPermissions += 'Write'
        }
        if ($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::ExecuteFile) {
            $userPermissions += 'Execute'
        }

        # Build and print the line using glyphs and show permissions of user
        if ($CurrentDepth -eq 0) {
            $branch = ''
        }
        elseif ($IsLast) {
            $branch = $g_l
        }
        else {
            $branch = $g_t
        }

        if ($CurrentDepth -eq 0) {
            $linePrefix = "$Indent"
        }
        else {
            $linePrefix = "$Indent" + $branch + $g_h2 + " "
        }
        Write-Output ("$linePrefix$displayName : $User's Permissions: $($userPermissions -join ', ')")

        # Recursively process subdirectories if we haven't reached the max depth
        if ($CurrentDepth -lt $Depth) {
            # Try to list children; treat empty result as 'no children' (do not print a message)
            $rawChildren = @(Get-ChildItem -Path $Path -ErrorAction SilentlyContinue)
            if ($rawChildren.Count -eq 0) {
                # Second attempt: try with -Force and -Directory (handles hidden/system and provider differences)
                $rawChildren = @(Get-ChildItem -Path $Path -Directory -Force -ErrorAction SilentlyContinue)
            }

            # Recurse into them if enumeration succeeded and no child directories are found
            $subDirectories = @($rawChildren | Where-Object { $_.PSIsContainer })
            if ($subDirectories.Count -gt 0) {
                for ($i = 0; $i -lt $subDirectories.Count; $i++) {
                    $subDir = $subDirectories[$i]
                    $isLastChild = ($i -eq ($subDirectories.Count - 1))

                    # Extend indent with vertical line if this node is not the last
                    if ($CurrentDepth -eq 0) {
                        $childIndent = ''
                    }
                    else {
                        if ($IsLast) {
                            $childIndent = '    '
                        }
                        else {
                            $childIndent = $g_v + '   '
                        }
                    }
                    $newIndent = $Indent + $childIndent
                    # Call recursively and mark whether it's the last child
                    Get-DirectoryTree -Path $subDir.FullName -Depth $Depth -CurrentDepth ($CurrentDepth + 1) -Indent $newIndent -IsLast $isLastChild
                }
            }
        }
    }

    # Start the recursive process
    Get-DirectoryTree -Path $Path -Depth $Depth
}

# Export the function to make it available when the module is imported
Export-ModuleMember -Function Get-PermissionTree
# End of Get-PermissionTree.psm1