# Export and Archive Virtual Machines

## Overview
The **Export and Archive** functionality in Hyper-V Manager allows administrators to create backups of virtual machines (VMs) for storage or migration purposes. This page explains the difference between exporting a VM and archiving it.

## Export
The **Export** feature allows you to create a backup of a VM by saving all its files, including VHDX files, configuration settings, and snapshots, to a designated folder. The exported files retain their original format, making it easy to restore or migrate the VM later. The exported VM is stored in the `$BasePath\Export` directory, automatically created if it does not exist.

<img style="border: 1px solid gray;" src="https://github.com/jamesrmilne/Hyper-V-Manager/blob/main/ScreenShots/HVM%20Export%20Folder.png" />

## Archive
The **Archive** feature builds upon the Export function by compressing the exported VM files into a single ZIP archive. This helps reduce storage space and is useful for long-term retention of VM backups. Once a VM is exported, it is automatically zipped and stored in the `$BasePath\Archive` directory. This ensures efficient space management and keeps backup files organized.

<img style="border: 1px solid gray;" src="https://github.com/jamesrmilne/Hyper-V-Manager/blob/main/ScreenShots/HVM%20Archive%20Folder.png" />

## Folder Structure
Both **Export** and **Archive** folders are automatically created based on the `$BasePath` variable, ensuring organized storage of exported and archived VMs.

- **Export Path**: `$BasePath\Export\<VMName>`
- **Archive Path**: `$BasePath\Archive\<VMName>.zip`

## How to Export a VM
1. Select the VM you want to export.
2. Click the **Export** button.
3. The VM’s files (VHDX, configuration, and snapshots) will be saved to `$BasePath\Export\<VMName>`.

## How to Archive a VM
1. Select the VM you want to archive.
2. Click the **Archive** button.
3. The VM will first be exported to `$BasePath\Archive\<VMName>`.
4. The exported files will be compressed into a ZIP file and moved to `$BasePath\Archive\<VMName>.zip`.

## Best Practices
- **Use Export for quick migrations**: Keep exported VMs uncompressed for easy restoration.
- **Use Archive for long-term storage**: Saves disk space and keeps backups organized.
- **Ensure sufficient disk space**: Both operations require adequate storage.
- **Automate archiving**: Schedule regular archives to maintain backup consistency.

## Further Reading
- [Microsoft Hyper-V Export Documentation](https://docs.microsoft.com/en-us/virtualization/hyper-v/)
- [PowerShell Commands for Hyper-V](https://docs.microsoft.com/en-us/powershell/module/hyper-v/)
