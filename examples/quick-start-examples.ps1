# Fabric Archive Bot v2.0 - Quick Start Examples

Write-Host "Fabric Archive Bot v2.0 - Quick Start Examples" -ForegroundColor Green
Write-Host "=" * 50

Write-Host "`n1. Basic Usage (Default Configuration):" -ForegroundColor Cyan
Write-Host "   .\Start-FabricArchiveBot.ps1" -ForegroundColor White
Write-Host "   (Uses FabricArchiveBot_Config.json by default)" -ForegroundColor Gray

Write-Host "`n2. Test Run (See What Would Be Archived):" -ForegroundColor Cyan
Write-Host "   .\Start-FabricArchiveBot.ps1 -WhatIf" -ForegroundColor White

Write-Host "`n3. Custom Configuration File:" -ForegroundColor Cyan
Write-Host "   .\Start-FabricArchiveBot.ps1 -ConfigPath '.\FabricArchiveBot_Config-Production.json'" -ForegroundColor White

Write-Host "`n4. Enable Parallel Processing (PowerShell 7+):" -ForegroundColor Cyan
Write-Host "   .\Start-FabricArchiveBot.ps1 -UseParallelProcessing" -ForegroundColor White
Write-Host "   (Automatically uses CPU core count as throttle limit)" -ForegroundColor Gray

Write-Host "`n5. Custom Throttle Limit for Parallel Processing:" -ForegroundColor Cyan
Write-Host "   .\Start-FabricArchiveBot.ps1 -UseParallelProcessing -ThrottleLimit 4" -ForegroundColor White

Write-Host "`n6. Custom Workspace Filter:" -ForegroundColor Cyan
Write-Host "   .\Start-FabricArchiveBot.ps1 -WorkspaceFilter `"(state eq 'Active') and contains(name,'Production')`"" -ForegroundColor White

Write-Host "`n7. Custom Target Folder:" -ForegroundColor Cyan
Write-Host "   .\Start-FabricArchiveBot.ps1 -TargetFolder 'C:\FabricBackups'" -ForegroundColor White

Write-Host "`n8. Skip Legacy Fallback (FabricTools Only):" -ForegroundColor Cyan
Write-Host "   .\Start-FabricArchiveBot.ps1 -SkipLegacyFallback" -ForegroundColor White

Write-Host "`n9. Migration from v1.0 to v2.0:" -ForegroundColor Cyan
Write-Host "   .\helpers\Migrate-ToV2.ps1 -TestMigration" -ForegroundColor White

Write-Host "`n10. Full Production Example:" -ForegroundColor Cyan
Write-Host "   .\Start-FabricArchiveBot.ps1 -ConfigPath '.\FabricArchiveBot_Config-Production.json' -UseParallelProcessing -ThrottleLimit 6 -TargetFolder 'D:\FabricArchives'" -ForegroundColor White

Write-Host "`n" + "=" * 50
Write-Host "For detailed help and parameter descriptions:" -ForegroundColor Yellow
Write-Host "   Get-Help .\Start-FabricArchiveBot.ps1 -Full" -ForegroundColor White

Write-Host "`nFor workspace filtering guide:" -ForegroundColor Yellow
Write-Host "   Get-Content .\docs\workspace-filtering-guide.md" -ForegroundColor White
