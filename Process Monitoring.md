# Process Monitoring

## Overview
The **Process Monitoring** page in Hyper-V Manager provides a real-time view of currently running processes on the system. It allows administrators to track resource usage and identify processes that may be consuming excessive memory or CPU resources.

## Process Information
The following details are displayed for each running process:

- **ID**: Unique identifier for the process.
- **Name**: The name of the process (e.g., chrome.exe, AggregatorHost.exe).
- **UserName**: The user account associated with the process.
- **Paged Memory Size**: The amount of memory allocated to the process that is stored in the paging file.
- **Virtual Memory Size**: The total virtual memory assigned to the process.
- **Path**: The file system location of the executable running the process.

## Commonly Monitored Processes
- **System Processes**: Core Windows services such as `AggregatorHost.exe` and `ApplicationFrameHost.exe`.
- **User Applications**: Programs actively running under a user session, such as `chrome.exe`.
- **Background Services**: Various system tasks that operate in the background without user interaction.

## Best Practices
- **Monitor High Resource Usage**: Identify processes consuming excessive memory or CPU and take appropriate action.
- **Check Running Applications**: Ensure that only necessary applications are running to optimize system performance.
- **Investigate Unknown Processes**: If an unfamiliar process is consuming significant resources, verify its legitimacy.
- **Terminate Unresponsive Applications**: If a process is causing system slowdowns, consider terminating it from Task Manager or PowerShell.

## Further Reading
- [Microsoft Process Monitoring Documentation](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/tasklist)
- [PowerShell Commands for Process Management](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-process)
