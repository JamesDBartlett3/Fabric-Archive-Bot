# Video Script Outline

## Introduction (0:00–1:00)

- Greet viewers
  - “Hi, I’m James Bartlett, and today we’ll be exploring a free, open-source solution I developed called Fabric Archive Bot, and I'll show you how to automate backups of your Power BI and Fabric workspaces.”
  - “I'd like to thank the conference organizers for putting in the hard work to make this conference possible, and for giving me the opportunity to share this with you today.”
  - “In this demo, I’ll cover the key concepts behind Fabric Archive Bot, I'll show you how to set up the script, run it manually, and schedule it for automatic backups using Windows Task Scheduler. This tool is designed to work with Power BI and Fabric, but for the sake of time and simplicity, I'll refer to both as 'Fabric' from now on.”
- Prerequisites:
  - Intermediate knowledge of the Fabric cloud service.
  - Tenant administrator access to Fabric, or someone who can provide the necessary permissions.
  - An Entra ID App Registration in Azure, or "Service Principal", which is how I'll refer to it from now on.
  - An Entra ID Security Group in Azure for the Service Principal, to grant it access to the read-only admin APIs in Fabric.
  - A Windows machine with PowerShell version 7+ and Windows Task Scheduler.

## Brief Overview of Key Concepts (1:00–2:30)

- REST API:
  - A standardized way for programs to communicate with each other over the internet.
- JSON (JavaScript Object Notation):
  - The standard format for sending and receiving data, commands, and configurations to and from REST APIs.
  - Fabric Archive Bot optionally reads its configuration data from JSON files, such as `Config.json`.
- Service Principal:
  - A Service Principal is kind of like a user account, but for automated processes that need to authenticate without human intervention.
- Windows Task Scheduler:
  - A built-in Windows utility that allows users to schedule tasks to run at specific times or events.
  - You can use it to run Fabric Archive Bot automatically every night at midnight, for example.

## Setting Up Fabric Archive Bot (2:30–5:00)

- Where to clone or download the repository.
- Service Principal in Azure.
  - App ID
  - App Secret
- Security Group in Azure.
- Fabric admin portal.
  - Grant the Security Group access to the read-only admin APIs.
  - Show where to find the Tenant ID.
- Open `Export-FabricItemsFromAllWorkspaces.ps1` briefly, highlighting its parameters and their descriptions.
- Open `Config.json`, show where to place Tenant ID, App ID, and App Secret for the Service Principal.
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
  - Create Service Principal
  - Add it to a new Entra ID Security Group
  - Grant that Security Group access to the read-only admin APIs in the Fabric admin portal.
- Configure JSON or set environment variable with AppId, AppSecret, and TenantId.
- Run the script manually or schedule it for automatic exports.
- Encourage viewers to contribute feedback and enhancements on GitHub.
