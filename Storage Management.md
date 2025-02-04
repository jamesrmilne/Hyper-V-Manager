# Storage Management

## Overview
The **Storage Management** page in Hyper-V Manager provides an overview of all storage volumes available on the system. It allows administrators to monitor disk health, available space, and filesystem types to ensure efficient storage utilization.

<img style="border: 1px solid gray;" src="https://github.com/jamesrmilne/Hyper-V-Manager/blob/main/ScreenShots/HVM%20Volumes.png" />

## Volume Information
The following details are displayed for each volume:

- **Drive Letter**: The assigned letter for the volume (e.g., C, D).
- **FileSystem Label**: A descriptive label for the volume (e.g., Storage, Win11).
- **FileSystem Type**: The type of filesystem used (e.g., NTFS, FAT32).
- **Health Status**: Indicates the current health of the volume (e.g., Healthy).
- **Size Remaining**: The available free space on the volume.
- **Total Size**: The total capacity of the volume.

## Best Practices
- **Monitor free space**: Ensure sufficient storage is available for VM operations and backups.
- **Use appropriate file systems**: NTFS is recommended for Hyper-V storage due to reliability and security features.
- **Regularly check disk health**: Identify and address potential disk failures before they impact performance.
- **Optimize storage usage**: Archive old backups and remove unnecessary files to maintain storage efficiency.

## Further Reading
- [Microsoft Storage Management Documentation](https://docs.microsoft.com/en-us/windows-server/storage/)
- [Hyper-V Storage Best Practices](https://docs.microsoft.com/en-us/virtualization/hyper-v/plan/plan-hyper-v-scalability-in-windows-server)
