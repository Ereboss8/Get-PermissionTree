# WIP!

# Start of Get-PermissionTree.psm1
function Get-PermissionTree {
    param(
        # Depth for how deep the tree goes (Standard: 1)
        [int]$Depth = 1,
        # Path to start from (Mandatory)
        [Parameter(Mandatory=$true)][string]$Path = ""
    )
    # Outputs
    Write-Host "Depth: $Depth"
    Write-Host "Path: $Path"
}

# Export the function to make it available when the module is imported
Export-ModuleMember -Function Get-PermissionTree
# End of Get-PermissionTree.psm1