# Get-PermissionTree

**A PowerShell module to recursively check and display directory permissions for a specified user.**

---

## Overview
`Get-PermissionTree` is a PowerShell function designed to help administrators and users visualize directory permissions in a tree-like structure. It recursively traverses directories up to a specified depth and displays the **Read**, **Write**, and **Execute** permissions for a given user.

---

## Features
✅ **Path Parameter**: The starting directory path (defaults to the current path)

✅ **User-Specific Permissions**: Checks permissions for a specified user (defaults to the current user if none is provided)

✅ **Depth Control**: Traverses directories up to a specified depth (defaults to 1).

✅ **Tree-Like Output**: Displays a hierarchical tree of directories with user permissions.

✅ **Permission Simplification**: Only shows **Read**, **Write**, and **Execute** permissions for clarity.

✅ **Access Handling**: Skips directories where the user has no permissions.

---

## Installation
1. **Save the Module**:
   Save the `Get-PermissionTree.psm1` file to a directory in your PowerShell module path (e.g., `$env:\Program Files\WindowsPowerShell\Modules\Get-PermissionTree`).

2. **Import the Module**:
   ```powershell
   Import-Module Get-PermissionTree -Force