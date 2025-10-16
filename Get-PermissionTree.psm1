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

    # Outputs (DELETE LATER WHEN DONE)
    Write-Host "User: $User"
    Write-Host "Path: $Path"
    Write-Host "Depth: $Depth"
}

# Export the function to make it available when the module is imported
Export-ModuleMember -Function Get-PermissionTree
# End of Get-PermissionTree.psm1