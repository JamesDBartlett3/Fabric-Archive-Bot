# Video Script Outline

## Introduction (0:00–1:00)

- Greet viewers
  - “Hi, I’m James Bartlett, and today we’ll be exploring a free, open-source solution I developed called Fabric Archive Bot, and I'll show you how to automate backups of your Power BI and Fabric workspaces.”
  - “I'd like to thank the Data Toboggan conference organizers for putting in the hard work to make this conference possible, and for giving me the opportunity to share this with you today.”
  - “In this demo, I’ll cover the key concepts behind Fabric Archive Bot, I'll show you how to set up the script, run it manually, and schedule it for automatic backups using Windows Task Scheduler. This tool is designed to work with Power BI and Fabric, but for the sake of time and simplicity, I'll refer to both as 'Fabric' from now on.”
- Prerequisites: 
  - Intermediate knowledge of the Fabric cloud service
  - Tenant administrator access to Fabric (or someone who can provide the necessary permissions)
  - An Azure Service Principal (Entra ID App Registration)
  - A Windows machine with PowerShell version 7+ and Windows Task Scheduler

## Brief Overview of Key Concepts (1:00–2:30)

- REST API (Representational State Transfer Application Programming Interface):
  - Allows systems to communicate over HTTP using standard methods like GET and POST.
  - Fabric provides REST API endpoints for retrieving and managing resources.
- JSON (JavaScript Object Notation):
  - The format used by REST APIs to exchange data, commands, and configurations.
  - Fabric Archive Bot also optionally reads its configuration data from JSON files, such as `Config.json`.
- PowerShell Module:
  - A set of functions that can be loaded into a PowerShell session.
  - Fabric Archive Bot imports several PowerShell Modules (e.g., FabricPS-PBIP) and uses functions from those modules to perform actions
    - Authenticating to Fabric.
    - Fetching data from REST API endpoints.
- Azure Service Principal (Entra ID App Registration):
  - An Azure Service Principal is a security identity used by applications, services, and automation tools to access Azure resources like Fabric.
  - It's kind of like a user account, but for automated processes that need to authenticate to Azure services without human intervention.
- Windows Task Scheduler:
  - A built-in Windows utility that allows users to schedule tasks to run at specific times or events.
  - You can use the Windows Task Scheduler to run Fabric Archive Bot automatically at regular intervals.

## Setting Up Fabric Archive Bot (2:30–5:00)

- Show where to clone or download the repository.
- Show the Service Principal in Azure.
- Show the Security Group in Azure.
- Show the Fabric admin portal.
- Open `Export-FabricItemsFromAllWorkspaces.ps1` briefly, highlighting its parameters and their descriptions.
- Open `Config.json`, show where to place Tenant ID, App ID, and App Secret for the Azure Service Principal.
- Open `IgnoreList.json`, show, and mention that only workspaces are supported at the moment.
- Show the `helpers` folder and briefly explain what the scripts inside it do.
  - `Register-FabricArchiveBotScheduledTask.ps1`
  - `Set-FabricArchiveBotUserEnvironmentVariable.ps1`

## Running the Script (5:00–7:30)

- Explain the script's main flow:
  - Get configuration data from `Config.json` or environment variable.
  - Authenticate to Fabric
  - Retrieve workspace IDs
  - Loop through workspaces
  - Export items from each workspace
  - Save the exported items to the target folder in year/month/day subfolders
- Run the script manually and show the exported items appearing in the target folder.

## Scheduling with Windows Task Scheduler (7:30–9:00)

Demonstrate creating a basic task:
- Run `helpers\Register-FabricArchiveBotScheduledTask.ps1`
- Open Windows Task Scheduler and show the new task.
- Run the task manually to demonstrate that it works.

## Conclusion (9:00–10:00)

Recap the process:
- Clone or download the repository.
- Azure setup
  - Create Azure Service Principal
  - Add it to a new Service Principal Security Group
  - Grant that Security Group access to the read-only admin APIs in the Fabric admin portal.
- Configure JSON or set environment variable with TenantId, AppId, and AppSecret.
- Run the script manually or schedule it for automatic exports.
- Encourage viewers to contribute feedback and enhancements on GitHub.