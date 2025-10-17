# WIP!

# Start of Get-PermissionTree.psm1
function Get-PermissionTree {
    param(
        # User to check permissions for (Standard: Current User)
        [string]$User = $env:USERNAME,
        # Depth for how deep the tree goes (Standard: 1)
        [int]$Depth = 1,
        # Path to start from (Mandatory)
        [Parameter(Mandatory=$true)][string]$Path = ""
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

    # Initialize the directory list
    $directoryList = New-Object System.Collections.ArrayList

    # Recursively collect directories
    function Get-DirectoryTree {
        param(
            [string]$Path,
            [int]$Depth,
            [int]$CurrentDepth = 0,
            [System.Collections.ArrayList]$DirectoryList
        )

        $DirectoryList.Add($Path) | Out-Null

        if ($CurrentDepth -lt $Depth) {
            $subDirectories = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
            foreach ($subDir in $subDirectories) {
                Get-DirectoryTree -Path $subDir.FullName -Depth $Depth -CurrentDepth ($CurrentDepth + 1) -DirectoryList $DirectoryList
            }
        }
    }

    Get-DirectoryTree -Path $Path -Depth $Depth -DirectoryList $directoryList

    # Outputs (DELETE LATER WHEN DONE)
    Write-Host "User: $User"
    Write-Host "Path: $Path"
    Write-Host "Depth: $Depth"
    Write-Host "Directories found: "
    $DirectoryList | ForEach-Object { Write-Host $_ }
}

# Export the function to make it available when the module is imported
Export-ModuleMember -Function Get-PermissionTree
# End of Get-PermissionTree.psm1