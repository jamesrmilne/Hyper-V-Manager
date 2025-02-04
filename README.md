# Welcome to Hyper-V-Manager

Hyper-V-Manager (HVM) is a light weight web UI for managing Hyper-V on windows desktop or server. 

## Overview
Hyper-V-Manager is a simple web tool built into help manage Windows Hyper-V that allows you to Manage, backup, and monitor virtual machines (VMs) on Windows-based systems. It provides an intuitive interface for configuring and maintaining virtualized environments.

<img style="border: .5px solid;" src="https://github.com/jamesrmilne/Hyper-V-Manager/blob/main/ScreenShots/HVM%20Home.png" />

## Features
- [Manage Virtual Machines](./Manage%20Virtual%20Machines.md): Easily start & stop VMs from a web browser. 
- [Export and Archive](./Export%20and%20Archive.md): Take VM exports for rollback or backup purposes. Archiving a VM with Export and Zip the VM to save storage.
- [Storage Management](./Storage%20Management.md): View and Monitor the host voluumes to ensure free space does not degrade performance.
- [Process Monitoring](./Process%20Monitoring.md): View the current processes running on the Host System. View real-time CPU, memory, and disk usage statistics.
- [Running Jobs](./Monitor%20Jobs.md): Administer Hyper-V servers remotely via Hyper-V Manager or PowerShell.

## Installation
Hyper-V Manager is included with Windows Server and Windows 10/11 Pro & Enterprise. To enable it:

### Enable Hyper-V on Windows 10/11
1. Open **PowerShell** as Administrator and run:
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
   ```
2. Restart your computer when prompted.

## Getting Started
1. Simply download **Hyper-V-Manager-Web.ps1**.
2. Run **Hyper-V-Manager-Web.ps1** as Administrator.
3. Open a web browser and connect to localhost port 80 or 443.

## Useful Links
- [Microsoft Hyper-V Documentation](https://docs.microsoft.com/en-us/virtualization/hyper-v/)
- [Hyper-V PowerShell Commands](https://docs.microsoft.com/en-us/powershell/module/hyper-v/)
- [Hyper-V Blog](https://techcommunity.microsoft.com/t5/virtualization/bg-p/Virtualization)

## Contributing
We welcome contributions! Feel free to submit issues or pull requests to enhance this project.

## License
This project is licensed under the [MIT License](LICENSE).
