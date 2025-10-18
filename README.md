# Get-PermissionTree

A PowerShell module to recursively display directory permissions for a specified user in a beautiful tree view.

---

## 🌳 Overview
`Get-PermissionTree` helps you visualize directory permissions in a clear, tree-like structure. It recursively traverses folders up to a specified depth and shows **Read**, **Write**, and **Execute** permissions for any user.

---

## ✨ Features
- **Path Parameter**: Start from any directory (defaults to current path)
- **User-Specific Permissions**: Check permissions for any user (defaults to current user)
- **Depth Control**: Limit recursion depth (defaults to 1)
- **Tree Glyphs**: Uses Unicode box-drawing characters for a clear hierarchy
- **Permission Simplification**: Shows only **Read**, **Write**, and **Execute**
- **Access Handling**: Clearly marks directories you cannot access
- **Fast & Robust**: Handles errors gracefully and skips inaccessible folders

---

## 🚀 Installation
1. **Create the Module**
   - Save `Get-PermissionTree.psm1` in a folder named `Get-PermissionTree` under your PowerShell modules path (e.g., `$env:ProgramFiles\WindowsPowerShell\Modules\Get-PermissionTree`).
2. **Set Execution Policy**
   - If needed, allow local scripts:
     ```powershell
     Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
     ```
3. **Import the Module**
   - Load the module in your session:
     ```powershell
     Import-Module Get-PermissionTree -Force
     ```

---

## 📖 Usage
```powershell
# Show permissions for the current user in the current directory (depth 1)
Get-PermissionTree

# Show permissions for 'John' in C:\Folder1 (depth 2)
Get-PermissionTree -Path "C:\Folder1" -User "John" -Depth 2
```

---

## 🖼️ Example Output
```
C:\Test : John's Permissions: Read, Write, Execute
├ Folder1 : John's Permissions: Read, Execute
│   └ Folder1-1 : John's Permissions: Read
├ Folder2 : John's Permissions: Read, Write
└ Folder3 : [Access Denied]
```

---

## ⚙️ Parameters
- `-Path` (string): The root directory to start from. Defaults to current directory.
- `-User` (string): The username to check. Defaults to current user.
- `-Depth` (int): How deep to recurse. Defaults to 1.

---

## 📝 Notes
- The output uses Unicode box-drawing glyphs for clarity. If your console does not support these, try using Windows Terminal or VS Code's integrated terminal.
- Only **Read**, **Write**, and **Execute** permissions are shown for simplicity.
- Directories you cannot access are marked as `[Access Denied]`.

---

## 📚 License
GNU General Public License v3.0