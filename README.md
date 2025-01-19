# Fabric-Archive-Bot
A fully automated Microsoft Power BI/Fabric tenant backup solution written in PowerShell

## Features
- **Free & Open Source**: No licensing fees, no vendor lock-in, and full access to the source code. You can run the script on your own hardware or in your own cloud environment, and you can modify the code to suit your needs. If you find a bug or want to add a feature, you can create [an issue](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/new/choose) or [a pull request](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/fork). Please review the [LICENSE.txt](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/blob/main/LICENSE.txt) file for more information.
- **Premium Not Required**: Works with both Power BI Pro and Power BI Premium, so you don't need to pay for Premium to use this solution.
- **Export Reports, Semantic Models, Notebooks, and Spark Job Definitions**: Exports all reports, semantic models (formerly "datasets"), notebooks, and spark job definitions from all workspaces in your Power BI/Fabric tenant to a local directory.
- **Service Principal Support**: Can authenticate as an Entra ID App Registration (a.k.a. "Service Principal"), so you don't need to login with your user account. This is especially useful for running the script on a schedule in an unattended environment. *Note: You will need to create an App Registration in Entra ID, add it to a new security group, grant that group the necessary permissions in the Power BI Admin Portal, and then provide the Tenant ID, App ID, Object ID, and App Secret in the `Config.json` file.*
- **Fully Automated**: Run the script on a daily schedule to automatically back up all workspaces in your Power BI/Fabric tenant (use Task Scheduler in Windows or a similar tool).
- **Configurable**: Customize the target folder, semantic model format (TMSL/TMDL), workspaces to archive, retention policy, and more (run `Get-Help .\Export-FabricItemsFromAllWorkspaces.ps1 -Detailed` for more information).
- **Secure**: Uses Entra ID authentication to access the Fabric REST APIs, so you don't need to store your username and password in the script.

## Current Issues & Limitations
- **Windows Machine**: Runs on Windows in a local or cloud environment (physical or virtual machine), but does not currently support running as an Azure Function (a.k.a "serverless"). This feature is planned for a future release.
- **Local Storage**: Exports items to a local directory, but does not currently support exporting to Azure Blob Storage, Amazon S3, Google Cloud Storage, etc. This feature is planned for a future release.
- **Item Types**: Can only export reports, semantic models (formerly "datasets"), notebooks, and spark job definitions. This is [a limitation of the Microsoft Fabric REST APIs](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/item-definition-overview), and Microsoft has not yet made it clear if/when they will add support for exporting other item types.
- **Archive Compression**: Exports items as individual files in the specified output directory. Support for compressing archived items (e.g., as .ZIP files) is planned for a future release.
- **Error Handling & Logging**: If an error occurs during the export process, the script will continue without handling or logging it. This feature is planned for a future release.
- **Parallelism**: Exports only one item at a time. Support for exporting multiple items in parallel is planned for a future release.
- **Item Filtering**: Currently, the script will ignore all workspaces in the `IgnoreWorkspaces` list (see `IgnoreList.json`), but `IgnoreReports` and `IgnoreSemanticModels` are not currently supported. I am planning to work on adding these capabilities in a future release, but they're not on the roadmap yet, so if you would like to see them added sooner, please let me know by creating [an issue](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/new/choose) or [a pull request](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/fork).
- **Incremental Backups**: Always exports all supported items from all workspaces which match the `WorkspaceFilter` parameter and are not in the `IgnoreWorkspaces` list (see `IgnoreList.json`). If you have a large tenant, this could take a long time and consume a lot of storage space. Incremental backups are theoretically possible, but they would require a much more complex solution, so this feature is not currently on the roadmap. However, if you would like to see this feature added, please let me know by creating [an issue](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/new/choose) or [a pull request](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/fork).
- **Multiple Tenants**: Support for exporting items from multiple tenants is not currently supported or on the roadmap, but if you would like to see this feature added, please let me know by creating [an issue](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/new/choose) or [a pull request](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/fork).
- ~~**Corruption of embedded PNG image files**: This script leverages the `Export-FabricItems` function from [@RuiRomano](https://github.com/RuiRomano)'s `FabricPS-PBIP` module to export items like reports and semantic models from Microsoft Fabric. Currently, there is a bug that causes PNG image files embedded in reports (e.g. scrims, company logos, etc.) to become corrupted during the export process. [I reported this issue](https://github.com/microsoft/Analysis-Services/issues/266) in the `Analysis-Services` repo where the `FabricPS-PBIP` module is published, and [Rui is now looking into whether the bug is in his module or the underlying Fabric REST API](https://github.com/microsoft/Analysis-Services/issues/266#issuecomment-2182591274). I will update this section when I have more information.~~

## Usage
1. Clone this repository to your local machine or cloud environment.
2. Open the `Config.json` file in a text editor and fill in the required values for your Service Principal.
3. Open the `IgnoreList.json` file in a text editor and fill in the items you want to ignore.
4. Open a PowerShell terminal and navigate to the directory where you cloned this repository.
5. Run the following command to export all reports and semantic models from all workspaces in your Power BI/Fabric tenant to the specified output directory:
```powershell
.\Export-FabricItemsFromAllWorkspaces.ps1
```

## Notes
If you clone this repo, you can run these commands to prevent your changes to the `Config.json` and `IgnoreList.json` files from being tracked in Git (so you don't accidentally commit your sensitive information):
```bash
git update-index --skip-worktree Config.json
git update-index --skip-worktree IgnoreList.json
```

## Acknowledgements
This project was inspired by, and wouldn't be possible without, [the FabricPS-PBIP PowerShell module](https://github.com/microsoft/Analysis-Services/tree/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psm1), which was created by [Rui Romano](https://github.com/ruiromano), and can be found in the [Analysis-Services repository on GitHub](https://github.com/microsoft/Analysis-Services).
