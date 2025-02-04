# Monitor Jobs

## Overview
The **Monitor Jobs** page in Hyper-V Manager provides a real-time view of ongoing, completed, failed, and stopped tasks. This feature helps administrators track job execution statuses and identify any issues in the virtualization environment.

<img style="border: 1px solid gray;" src="https://github.com/jamesrmilne/Hyper-V-Manager/blob/main/ScreenShots/HVM%20Jobs.png" />

## Job Status Categories
The monitoring system classifies jobs into four categories:

### Running
- Displays jobs that are actively in progress.
- Provides details such as **Job ID, Name, and State**.
- Example: `Archive GPUVM01` currently running.

### Completed
- Lists jobs that have successfully finished.
- Shows the **Job ID, Name, and State**.
- Example: `Archive GPUVM03` marked as completed.

### Failed
- Identifies jobs that encountered errors or failed to execute.
- Currently, no failed jobs are listed in the screenshot.
- Administrators should review logs or error messages for troubleshooting.

### Stopped
- Displays jobs that were manually or automatically stopped.
- No stopped jobs are present in the provided screenshot.
- Stopped jobs can be restarted or investigated if necessary.

## Troubleshooting
- **Monitor running jobs** to ensure tasks complete successfully.
- **Review completed jobs** to confirm expected results.
- **Investigate failed jobs** immediately to prevent disruptions.
- **Manage stopped jobs** and determine if they should be resumed or restarted.
- **Check the log file** stored in `$BasePath\Logs` for detailed information on job execution and errors.

## Further Reading
- [Hyper-V Job Monitoring Documentation](https://docs.microsoft.com/en-us/virtualization/hyper-v/)
- [PowerShell Commands for Job Management](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-job)
