<#
.SYNOPSIS
Registers a Windows Scheduled Task for Fabric Archive Bot

.DESCRIPTION
Creates a Windows Scheduled Task to automatically run Fabric Archive Bot on a daily schedule.
Supports both v1.0 and v2.0 versions of the bot with automatic script detection and validation.

.PARAMETER TaskName
The name for the scheduled task. Default: "FabricArchiveBot"

.PARAMETER TaskDescription
Custom description for the scheduled task. If not provided, a version-appropriate description will be used.

.PARAMETER TaskCommand
The PowerShell executable to use. Default: Uses the current PowerShell 7+ executable path.

.PARAMETER TaskArguments
Custom arguments for the PowerShell command. If not provided, version-appropriate arguments will be used.

.PARAMETER TaskTime
The time to run the task daily in HH:MM format. Default: "00:00" (midnight)

.PARAMETER TaskUser
The user account to run the task under. Default: Current user

.PARAMETER Version
The version of Fabric Archive Bot to schedule. Valid values: "1", "2". Default: "2"

.EXAMPLE
.\Register-FabricArchiveBotScheduledTask.ps1

Creates a scheduled task for v2.0 (default) running daily at midnight.

.EXAMPLE
.\Register-FabricArchiveBotScheduledTask.ps1 -Version "1" -TaskTime "02:00"

Creates a scheduled task for v1.0 running daily at 2:00 AM.

.EXAMPLE
.\Register-FabricArchiveBotScheduledTask.ps1 -TaskName "FabricArchiveBot-Production" -Version "2" -TaskTime "23:30"

Creates a custom-named scheduled task for v2.0 running daily at 11:30 PM.

.NOTES
- Requires Administrator privileges to create scheduled tasks
- Automatically validates that the target script exists before creating the task
- Provides detailed feedback on task creation and configuration
#>

param(
  [string]$TaskName = "FabricArchiveBot",
  [string]$TaskDescription,
  [string]$TaskCommand = """$((Get-Command pwsh.exe).Source)""",
  [string]$TaskArguments,
  [string]$TaskTime = "00:00",
  [string]$TaskUser = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name),
  [ValidateSet("1", "2")]
  [string]$Version = "2"
)

# Set version-specific defaults if not provided
if (-not $TaskDescription) {
  if ($Version -eq "1") {
    [string]$TaskDescription = "Fabric Archive Bot v1.0 - Automatically create a daily archive of items from all Power BI/Fabric workspaces"
  }
  else {
    [string]$TaskDescription = "Fabric Archive Bot v2.0 - Automatically create a daily archive of items from all Power BI/Fabric workspaces"
  }
}

if (-not $TaskArguments) {
  if ($Version -eq "1") {
    [string]$TaskArguments = "-NoProfile -NoLogo -ExecutionPolicy Bypass -WindowStyle Hidden -File Export-FabricItemsFromAllWorkspaces.ps1"
  }
  else {
    [string]$TaskArguments = "-NoProfile -NoLogo -ExecutionPolicy Bypass -WindowStyle Hidden -File Start-FabricArchiveBot.ps1"
  }
}

# Validate that the target script exists
[string]$rootPath = Split-Path $PSScriptRoot
[string]$targetScript = if ($Version -eq "1") {
  Join-Path $rootPath "Export-FabricItemsFromAllWorkspaces.ps1"
}
else {
  Join-Path $rootPath "Start-FabricArchiveBot.ps1"
}

if (-not (Test-Path $targetScript)) {
  Write-Error "Target script not found: $targetScript"
  Write-Host "Available versions:" -ForegroundColor Yellow
  if (Test-Path (Join-Path $rootPath "Export-FabricItemsFromAllWorkspaces.ps1")) {
    Write-Host "  - v1.0 (Export-FabricItemsFromAllWorkspaces.ps1)" -ForegroundColor Green
  }
  if (Test-Path (Join-Path $rootPath "Start-FabricArchiveBot.ps1")) {
    Write-Host "  - v2.0 (Start-FabricArchiveBot.ps1)" -ForegroundColor Green
  }
  exit 1
}

Write-Host "Creating scheduled task for Fabric Archive Bot v$Version.0" -ForegroundColor Green
Write-Host "Target Script: $(Split-Path -Leaf $targetScript)" -ForegroundColor Cyan
Write-Host "Schedule: Daily at $TaskTime" -ForegroundColor Cyan

[Microsoft.PowerShell.Cmdletization.Cim.CimMethodResult]$taskTrigger = New-ScheduledTaskTrigger -Daily -At $TaskTime
[Microsoft.PowerShell.Cmdletization.Cim.CimMethodResult]$taskAction = New-ScheduledTaskAction -Execute $TaskCommand -Argument $TaskArguments -WorkingDirectory $(Split-Path $PSScriptRoot)
[Microsoft.PowerShell.Cmdletization.Cim.CimMethodResult]$taskPrincipal = New-ScheduledTaskPrincipal -UserId $TaskUser -LogonType ServiceAccount

# Register the scheduled task
try {
  Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Trigger $taskTrigger -Action $taskAction -Principal $taskPrincipal
  Write-Host "`nScheduled task '$TaskName' created successfully!" -ForegroundColor Green
  Write-Host "Task Details:" -ForegroundColor Cyan
  Write-Host "  - Version: v$Version.0" -ForegroundColor White
  Write-Host "  - Script: $(Split-Path -Leaf $targetScript)" -ForegroundColor White  
  Write-Host "  - Schedule: Daily at $TaskTime" -ForegroundColor White
  Write-Host "  - User: $TaskUser" -ForegroundColor White
  Write-Host "`nYou can view and manage this task in Windows Task Scheduler." -ForegroundColor Yellow
}
catch {
  Write-Error "Failed to create scheduled task: $($_.Exception.Message)"
  Write-Host "Make sure you're running this script as an Administrator." -ForegroundColor Yellow
  exit 1
}