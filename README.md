# Welcome to Hyper-V-Manager

Hyper-V-Manager (HVM) is a light weight web UI for managing Hyper-V. 

![Hyper-V Manager](https://upload.wikimedia.org/wikipedia/en/e/e0/Hyper-V_Logo.png)

## Overview
Hyper-V-Manager is a simple web tool built into help manage Windows Hyper-V that allows you to Manage, backup, and monitor virtual machines (VMs) on Windows-based systems. It provides an intuitive interface for configuring and maintaining virtualized environments.

## Features
- **Manage Virtual Machines**: Easily start & stop VMs. 
- **Export & Archive**: Take VM exports for rollback or backup purposes. Archiving a VM with Export and Zip the VM to save storage.
- **Storage Management**: View and Monitor the host voluumes to ensure free space does not degrade performance.
- **Process Monitoring**: View the current processes running on the Host System. View real-time CPU, memory, and disk usage statistics.
- **Running Jobs**: Administer Hyper-V servers remotely via Hyper-V Manager or PowerShell.

## Installation
Hyper-V Manager is included with Windows Server and Windows 10/11 Pro & Enterprise. To enable it:

### Enable Hyper-V on Windows 10/11
1. Open **PowerShell** as Administrator and run:
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
   ```
2. Restart your computer when prompted.

### Enable Hyper-V on Windows Server
1. Open **Server Manager** and navigate to **Add Roles and Features**.
2. Select **Hyper-V** and follow the installation wizard.
3. Restart your system to complete the installation.

## Getting Started
1. Open **Hyper-V Manager** from the Start menu.
2. Click **New > Virtual Machine** to create your first VM.
3. Configure CPU, memory, and disk settings.
4. Install an operating system on the VM and start using it!

## Useful Links
- [Microsoft Hyper-V Documentation](https://docs.microsoft.com/en-us/virtualization/hyper-v/)
- [Hyper-V PowerShell Commands](https://docs.microsoft.com/en-us/powershell/module/hyper-v/)
- [Hyper-V Blog](https://techcommunity.microsoft.com/t5/virtualization/bg-p/Virtualization)

## Contributing
We welcome contributions! Feel free to submit issues or pull requests to enhance this project.

## License
This project is licensed under the [MIT License](LICENSE).
