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

        # Get the ACL for the current directory
        $acl = Get-Acl -Path $Path -ErrorAction SilentlyContinue
        if (-not $acl) {
            Write-Output "$Indent$Path : [Access Denied]"
            return
        }

        # Check if the user has any permissions
        $permissions = $acl.Access | Where-Object { $_.IdentityReference -eq $fullUsername }
        if (-not $permissions) {
            Write-Output "$Indent$Path : $User has no explicit permissions."
            return
        }

        # Simplify permissions to Read, Write, and Execute
        $userPermissions = @()
        foreach ($permission in $permissions) {
            if ($permission.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Read) {
                $userPermissions += "Read"
            }
            if ($permission.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Write) {
                $userPermissions += "Write"
            }
            if ($permission.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::ExecuteFile) {
                $userPermissions += "Execute"
            }
        }

        # Print the current directory and its permissions
        Write-Output "$Indent$Path : $User's Permissions: $($userPermissions -join ', ')"

        # Recursively process subdirectories if we haven't reached the max depth
        if ($CurrentDepth -lt $Depth) {
            $subDirectories = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
            foreach ($subDir in $subDirectories) {
                Get-DirectoryTree -Path $subDir.FullName -Depth $Depth -CurrentDepth ($CurrentDepth + 1) -Indent ("$Indent    ")
            }
        }
    }

    # Start the recursive process
    Get-DirectoryTree -Path $Path -Depth $Depth
}

# Export the function to make it available when the module is imported
Export-ModuleMember -Function Get-PermissionTree
# End of Get-PermissionTree.psm1