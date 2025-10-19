# Start of Get-PermissionTree.psm1
function Get-PermissionTree {
    [CmdletBinding()]
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

        # Build branch glyph and line prefix
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
            $linePrefix = "$Indent" + $branch + "$g_h$g_h" + " "
        }

        # Determine display name
        if ($CurrentDepth -eq 0) {
            $displayName = $Path # Root uses full path
        }
        else {
            $displayName = Split-Path -Path $Path -Leaf # Children use leaf name
        }

        # Get ACL for the current directory; if we can't, report access denied
        try {
            $acl = Get-Acl -Path $Path -ErrorAction Stop
        }
        catch {
            Write-Output ("$linePrefix$displayName : [Access Denied]")
            return
        }

        # Build identity candidates to check for effective permissions for the specified user
        $identityCandidates = @()
        $identityCandidates += $fullUsername
        $identityCandidates += $User
        $identityCandidates += "$env:COMPUTERNAME\$User"
        if ($env:USERDOMAIN) { $identityCandidates += "$env:USERDOMAIN\$User" }
        $identityCandidates += "BUILTIN\Users"
        $identityCandidates += "NT AUTHORITY\Authenticated Users"
        $identityCandidates += "Everyone"

        # Resolve user SID and add to candidates
        $userSID = $null
        try {
            $ntAcc = $null
            try { $ntAcc = New-Object System.Security.Principal.NTAccount($User) } catch { }
            if (-not $ntAcc) { try { $ntAcc = New-Object System.Security.Principal.NTAccount("$env:COMPUTERNAME\$User") } catch { } }
            if ($ntAcc) { $userSID = $ntAcc.Translate([System.Security.Principal.SecurityIdentifier]).Value; $identityCandidates += $userSID }
        } catch { $userSID = $null }

        # Try local group enumeration (best-effort) to include groups the user belongs to
        try {
            $localGroups = Get-LocalGroup -ErrorAction SilentlyContinue
            if ($localGroups) {
                foreach ($g in $localGroups) {
                    try {
                        $members = Get-LocalGroupMember -Group $g.Name -ErrorAction SilentlyContinue
                        if ($members) {
                            foreach ($m in $members) {
                                if (($m.Name -eq $fullUsername) -or ($m.Name -eq $User) -or ($m.Name -like "*\$User") -or ($m.SID -and $m.SID -eq $userSID)) {
                                    $identityCandidates += ("$env:COMPUTERNAME\$($g.Name)")
                                    $identityCandidates += $g.Name
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

        # Fallback: try WMI to find additional group names by SID (best-effort)
        if ($userSID) {
            try {
                $groups = Get-WmiObject Win32_GroupUser | Where-Object { $_.PartComponent -match $userSID } | ForEach-Object { $_.GroupComponent -match 'Name="([^"]+)"' | Out-Null; $matches[1] }
                foreach ($gn in $groups) { $identityCandidates += ("$env:COMPUTERNAME\$gn"); $identityCandidates += $gn }
            } catch { }
        }

        # Build a set of identity SIDs for comparison
        $identitySids = @()
        if ($userSID) { $identitySids += $userSID }
        foreach ($cand in $identityCandidates) {
            try {
                $sid = (New-Object System.Security.Principal.NTAccount($cand)).Translate([System.Security.Principal.SecurityIdentifier]).Value
                if ($sid) { $identitySids += $sid }
            } catch { }
        }

        # Match ACL entries to any of the identity candidates to derive effective permissions
        $matchedAces = @()
        foreach ($ace in $acl.Access) {
            $aceRaw = $ace.IdentityReference.Value
            # Try to get ACE SID for reliable comparison
            try { $aceSid = $ace.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $aceSid = $null }
            try { $aceName = $ace.IdentityReference.Translate([System.Security.Principal.NTAccount]).Value } catch { $aceName = $aceRaw }
                Write-Verbose ("ACE: $aceRaw -> $aceName (SID=$aceSid) Type=$($ace.AccessControlType) Rights=$($ace.FileSystemRights)")

            if (($aceSid -and ($identitySids -contains $aceSid)) -or
                ($aceName -and ($identityCandidates -contains $aceName)) -or
                ($identityCandidates -contains $aceRaw) -or
                ($aceRaw -like "*\$User")) {
                    Write-Verbose ("Matched ACE: $aceName / $aceRaw / $aceSid")
                $matchedAces += $ace
            }
        }

        # If nothing matched directly, consider permissive entries for Everyone / Authenticated Users
        if ($matchedAces.Count -eq 0) {
            foreach ($ace in $acl.Access) {
                $aceRaw = $ace.IdentityReference.Value
                if (($aceRaw -eq 'Everyone' -or $aceRaw -eq 'NT AUTHORITY\\Authenticated Users' -or $aceRaw -eq 'BUILTIN\\Users') -and $ace.AccessControlType -ne 'Deny') {
                    $matchedAces += $ace
                    break
                }
            }
        }

        # Include inherited permissions from parent (container inherit)
        if ($CurrentDepth -gt 0) {
            try {
                $parent = Split-Path -Path $Path -Parent
                $parentAcl = Get-Acl -Path $parent -ErrorAction Stop
                foreach ($ace in $parentAcl.Access) {
                    if ($ace.PropagationFlags -ne "NoPropagateInherit" -and $ace.InheritanceFlags -match "ContainerInherit|ObjectInherit") {
                        if ($identityCandidates -contains $ace.IdentityReference.Value -or $identityCandidates -contains $ace.IdentityReference.ToString() -or $ace.IdentityReference.Value -like "*\$User") {
                            $matchedAces += $ace
                        }
                    }
                }
            } catch { }
        }

        # Aggregate allowed and denied rights separately
        $allowedRights = 0
        $deniedRights = 0
        foreach ($ace in $matchedAces) {
            try { $rights = [int]$ace.FileSystemRights } catch { $rights = 0 }
            if ($ace.AccessControlType -eq 'Deny') { $deniedRights = $deniedRights -bor $rights } else { $allowedRights = $allowedRights -bor $rights }
        }

        # Remove denied bits from allowed bits to get effective rights
        $effectiveRights = $allowedRights -band (-bnot $deniedRights)

        # Decide booleans for Read/Write/Execute from effectiveRights
        $hasRead = (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::ReadData) -ne 0) -or (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::ListDirectory) -ne 0) -or (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::Read) -ne 0)
        $hasWrite = (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::WriteData) -ne 0) -or (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::Write) -ne 0) -or (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::CreateFiles) -ne 0) -or (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::CreateDirectories) -ne 0) -or (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::Delete) -ne 0)
        $hasExecute = (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::ExecuteFile) -ne 0) -or (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::Traverse) -ne 0) -or (($effectiveRights -band [int][System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0)

        # If the specified user has none of Read/Write/Execute, treat as Access Denied and don't recurse
        if (-not ($hasRead -or $hasWrite -or $hasExecute)) {
            Write-Output ("$linePrefix$displayName : [Access Denied]")
            return
        }

        # Build explicit permission string showing presence or absence
        $permList = @()
    if ($hasRead) { $permList += 'Read' } else { $permList += 'No Read' }
    if ($hasWrite) { $permList += 'Write' } else { $permList += 'No Write' }
    if ($hasExecute) { $permList += 'Execute' } else { $permList += 'No Execute' }
        $permissionString = $permList -join ', '
        Write-Output ("$linePrefix$displayName : $User's Permissions: $permissionString")

        # Recursively process subdirectories if we haven't reached the max depth and the user can traverse/read
        if ($CurrentDepth -lt $Depth -and ($hasRead -or $hasExecute)) {
            $rawChildren = @(Get-ChildItem -Path $Path -Directory -Force -ErrorAction SilentlyContinue)
            $subDirectories = @($rawChildren | Where-Object { $_.PSIsContainer })
            if ($subDirectories.Count -gt 0) {
                for ($i = 0; $i -lt $subDirectories.Count; $i++) {
                    $subDir = $subDirectories[$i]
                    $isLastChild = ($i -eq ($subDirectories.Count - 1))
                    if ($CurrentDepth -eq 0) { $childIndent = '' } else { if ($IsLast) { $childIndent = '    ' } else { $childIndent = $g_v + '   ' } }
                    $newIndent = $Indent + $childIndent
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