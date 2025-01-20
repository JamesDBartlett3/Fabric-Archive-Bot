param(
  [string]$TaskName = "FabricArchiveBot",
  [string]$TaskDescription = "Fabric Archive Bot - Automatically create a daily archive of items from all Power BI/Fabric workspaces",
  [string]$TaskCommand = """$((Get-Command pwsh.exe).Source)""",
  [string]$TaskArguments = "-NoProfile -NoLogo -ExecutionPolicy Bypass -WindowStyle Hidden -File Export-FabricItemsFromAllWorkspaces.ps1",
  [string]$TaskTime = "00:00",
  [string]$TaskUser = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
)

$taskTrigger = New-ScheduledTaskTrigger -Daily -At $TaskTime
$taskAction = New-ScheduledTaskAction -Execute $TaskCommand -Argument $TaskArguments -WorkingDirectory $(Split-Path $PSScriptRoot)
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $TaskUser -LogonType ServiceAccount

# Register the scheduled task
Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Trigger $taskTrigger -Action $taskAction -Principal $taskPrincipal