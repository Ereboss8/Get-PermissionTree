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
1. **Create the Module**:
   Create the `Get-PermissionTree.psm1` file in a directory in your PowerShell module path (e.g., `$env:\Program Files\WindowsPowerShell\Modules\Get-PermissionTree`) and copy-paste the code into it.
2. **Set Execution Policy**:
   To be able to use local scripts without a signature, you first have to set the execution policy on your Localmachine to `RemoteSigned`, if you haven't already.
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
3. **Import the Module**:
   ```powershell
   Import-Module Get-PermissionTree -Force

---

## Usage
```powershell
# Check permissions for the current user in the current path (depth 1)
Get-PermissionTree

# Check permissions for "John" in C:\Folder1 (depth 2)
Get-PermissionTree -Path "C:\Folder1" -User "John" -Depth 2