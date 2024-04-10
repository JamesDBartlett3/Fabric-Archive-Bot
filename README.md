# Fabric-Archive-Bot
A fully automated Microsoft Fabric/Power BI tenant backup solution written in PowerShell

## Features
- **Service Principal Support**: Can authenticate as an Azure AD App Registration (a.k.a. "Service Principal"), so you don't need to login with your user account. This is especially useful for running the script on a schedule in an unattended environment. *Note: You will need to create an App Registration in Azure AD, add it to a new security group, grant that group the necessary permissions in the Power BI Admin Portal, and then provide the Tenant ID, App ID, and App Secret in the `Config.json` file.*
- **Fully Automated**: Run on a daily schedule to automatically back up all workspaces in your Fabric tenant (use Task Scheduler in Windows or a similar tool).
- **Configurable**: Customize the target folder, semantic model format (TMSL/TMDL), workspaces to archive, retention policy, and more (run `Get-Help .\Export-FabricItemsFromAllWorkspaces.ps1 -Detailed` for more information).
- **Secure**: Uses Azure AD authentication to access the Fabric REST APIs, so you don't need to store your username and password in the script.

## Current Limitations
- **Azure Function**: Will run on a local machine or server, but does not currently support running as an Azure Function. This feature is planned for a future release.
- **Item Types**: Can only export reports and semantic models (formerly "datasets"). This limitation is imposed by the Fabric REST APIs, and Microsoft has not yet made it clear if or when they will add support for exporting other item types.
- **Archive Compression**: Exports items as individual files in the specified output directory. Support for compressing archived items (e.g., as .ZIP files) is planned for a future release.
- **Error Handling & Logging**: If an error occurs during the export process, the script will continue without handling or logging it. This feature is planned for a future release.
- **Parallelism**: Exports only one item at a time. Support for exporting multiple items in parallel is planned for a future release.
- **Item Filtering**: Currently, the script will ignore all workspaces in the `IgnoreWorkspaces` list (see `IgnoreList.json`), but `IgnoreReports` and `IgnoreSemanticModels` are not currently supported. I am planning to work on adding these capabilities in a future release, but they're not on the roadmap yet, so if you would like to see them added sooner, please let me know by creating [an issue](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/new/choose) or [a pull request](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/fork).
- **Incremental Backups**: Always exports all supported items from all workspaces which match the `WorkspaceFilter` parameter and are not in the `IgnoreWorkspaces` list (see `IgnoreList.json`). If you have a large tenant, this could take a long time and consume a lot of storage space. Incremental backups are theoretically possible, but they would require a much more complex solution, so this feature is not currently on the roadmap. However, if you would like to see this feature added, please let me know by creating [an issue](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/new/choose) or [a pull request](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/fork).
- **Multiple Tenants**: Support for exporting items from multiple tenants is not currently supported or on the roadmap, but if you would like to see this feature added, please let me know by creating [an issue](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/new/choose) or [a pull request](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/fork).

## Notes
If you clone this repo, you can run these commands to prevent your changes to the `Config.json` and `IgnoreList.json` files from being tracked in Git (so you don't accidentally commit your sensitive information):
```bash
git update-index --skip-worktree Config.json
git update-index --skip-worktree IgnoreList.json
```

## Acknowledgements
This project was inspired by, and wouldn't be possible without, [the FabricPS-PBIP PowerShell module](https://github.com/microsoft/Analysis-Services/tree/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psm1), which was created by [Rui Romano](https://github.com/ruiromano), and can be found in the [Analysis-Services repository on GitHub](https://github.com/microsoft/Analysis-Services).
