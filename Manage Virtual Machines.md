# Manage Virtual Machines

## Overview
The **Manage Virtual Machines** page in Hyper-V Manager provides an interface to monitor and control virtual machines (VMs) running on a Hyper-V host. It allows administrators to start, stop, pause, and manage resources for each VM efficiently.

## Table Breakdown
The page displays a table with the following key details for each virtual machine:

- **Name**: The identifier of the VM.
- **State**: The current status of the VM (e.g., Running, Off, Saved).
- **Status**: General health and operational status (e.g., Operating normally).
- **Memory Assigned**: Amount of memory allocated to the VM.
- **Processor Count**: Number of virtual processors assigned to the VM.
- **Actions**: Interactive controls to manage the VM.

## Available Actions
Each VM has a set of action buttons for management:

- **Start (▶️ Green)** - Powers on a VM that is turned off.
- **Stop (⏹️ Red)** - Shuts down a running VM.
- **Pause (⏸️ Blue)** - Pauses a running VM.
- **Export (▶️ Blue)** - Exports the VM to disk.
- **Archive (📂 Yellow)** - Exports the VM to disk and then Zips the folder.
- **Optimise (♻️ Green)** - Deletes or refreshes a VM entry.

## Managing Virtual Machines
To manage a VM:
1. Identify the desired VM from the list.
2. Click the appropriate action button to control the VM.
3. Monitor the status column to confirm changes.
4. For long running Jobs check the Jobs page.

## Best Practices
- Allocate memory and processor resources efficiently based on workload.
- Use snapshots before making major changes to VMs.
- Regularly review and remove unused VMs to free resources.
- Monitor VM performance to ensure smooth operation.

## Further Reading
- [Microsoft Hyper-V Documentation](https://docs.microsoft.com/en-us/virtualization/hyper-v/)
- [Hyper-V PowerShell Commands](https://docs.microsoft.com/en-us/powershell/module/hyper-v/)
