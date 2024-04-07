# Fabric-Archive-Bot
A fully automated Microsoft Fabric/Power BI tenant backup solution written in PowerShell

## Acknowledgements
This project was inspired by, and wouldn't be possible without, [the FabricPS-PBIP PowerShell module](https://github.com/microsoft/Analysis-Services/tree/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psm1), which was created by [Rui Romano](https://github.com/ruiromano), and can be found in the [Analysis-Services repository on GitHub](https://github.com/microsoft/Analysis-Services).

## Notes
Run this command to prevent your changes to the Config.json and IgnoreList.json files from being tracked in Git:
```bash
git update-index --skip-worktree Config.json
git update-index --skip-worktree IgnoreList.json
```