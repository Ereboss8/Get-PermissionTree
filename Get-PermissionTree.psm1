# Start of Get-PermissionTree.psm1
function Get-PermissionTree {
    param(
        # User to check permissions for (Default: Current User)
        [string]$User = $env:USERNAME,
        # Depth for how deep the tree goes (Default: 1)
        [int]$Depth = 1,
        # Path to start from (Default: Current path)
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

    # Recursively process directories and print permissions
    function Get-DirectoryTree {
        param(
            [string]$Path,
            [int]$Depth,
            [int]$CurrentDepth = 0,
            [string]$Indent = ""
        )

        # Check if the user can actually access the directory
        try {
            $null = Get-ChildItem -Path $Path -ErrorAction Stop
        }
        catch {
            Write-Output "$Indent$Path : [Access Denied]"
            return
        }

        # Get the ACL for the current directory
        try {
            $acl = Get-Acl -Path $Path -ErrorAction Stop
        }
        catch {
            Write-Output "$Indent$Path : [Access Denied]"
            return
        }

        # Check if the user has any explicit permissions
        $permissions = $acl.Access | Where-Object { $_.IdentityReference -eq $fullUsername }
        if (-not $permissions) {
            Write-Output "$Indent$Path : $User has no explicit permissions."
            return
        }

        # Check if the user has at least read access
        $hasReadAccess = $false
        foreach ($permission in $permissions) {
            if ($permission.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Read) {
                $hasReadAccess = $true
                break
            }
        }

        if (-not $hasReadAccess) {
            Write-Output "$Indent$Path : [Access Denied - No Read Permission]"
            return
        }

        # Simplify permissions to Read, Write, and Execute
        $userPermissions = @()
        foreach ($permission in $permissions) {
            if ($permission.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Read) {
                if (-not ($userPermissions -contains "Read")) {
                    $userPermissions += "Read"
                }
            }
            if ($permission.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Write) {
                if (-not ($userPermissions -contains "Write")) {
                    $userPermissions += "Write"
                }
            }
            if ($permission.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::ExecuteFile) {
                if (-not ($userPermissions -contains "Execute")) {
                    $userPermissions += "Execute"
                }
            }
        }

        # Print the current directory and its permissions
        Write-Output "$Indent$Path : $User's Permissions: $($userPermissions -join ', ')"

        # Recursively process subdirectories if we haven't reached the max depth
        if ($CurrentDepth -lt $Depth) {
            try {
                $subDirectories = Get-ChildItem -Path $Path -Directory -ErrorAction Stop
                foreach ($subDir in $subDirectories) {
                    Get-DirectoryTree -Path $subDir.FullName -Depth $Depth -CurrentDepth ($CurrentDepth + 1) -Indent ("$Indent    ")
                }
            }
            catch {
                Write-Output "$Indent  [Could not access subdirectories]"
            }
        }
    }

    # Start the recursive process
    Get-DirectoryTree -Path $Path -Depth $Depth
}

# Export the function to make it available when the module is imported
Export-ModuleMember -Function Get-PermissionTree
# End of Get-PermissionTree.psm1
