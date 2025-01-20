param(
  [string]$TaskName = "FabricArchiveBot",
  [string]$TaskDescription = "Fabric Archive Bot",
  [string]$TaskCommand = "pwsh.exe -ExecutionPolicy Bypass -File C:\FabricArchiveBot\Export-FabricItemsFromAllWorkspaces.ps1",
  [string]$TaskTime = "00:00",
  [string]$TaskUser = "LOCALSERVICE"
)

$taskTrigger = New-ScheduledTaskTrigger -Daily -At $TaskTime
$taskAction = New-ScheduledTaskAction -Execute $TaskCommand
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $TaskUser -LogonType ServiceAccount

Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Trigger $taskTrigger -Action $taskAction -Principal $taskPrincipal
