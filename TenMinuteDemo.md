# Video Script Outline

## Introduction (0:00–1:00)

- Greet viewers
- Introduce self and topic: 
  - “Hi, I’m James Bartlett, and today we’ll be exploring how to automate a daily backup of items from all Fabric workspaces using a free, open-source solution I developed called Fabric Archive Bot.”
- Mention prerequisites: 
  - Intermediate Power BI/Fabric knowledge
  - Some PowerShell basics
  - An Azure Service Principal with Power BI Service permissions
  - A Windows machine with PowerShell 7+ and Windows Task Scheduler (or another scheduling tool)

## Brief Overview of Key Concepts (1:00–2:30)

- REST API (Representational State Transfer Application Programming Interface):
  - Allows systems to communicate over HTTP using standard methods like GET and POST.
  - Power BI/Fabric provides REST API endpoints for retrieving and managing resources.
- JSON (JavaScript Object Notation):
  - The format used by REST APIs to exchange data, commands, and configurations.
  - Fabric Archive Bot also reads config data (like credentials) from JSON files, such as Config.json.
- PowerShell Module:
  - A set of functions that can be loaded into a PowerShell session.
  - Fabric Archive Bot imports several PowerShell Modules (e.g., FabricPS-PBIP) and uses functions from those modules to perform actions
    - Authenticating to Power BI/Fabric.
    - Fetching data from REST API endpoints.
- Azure Service Principal (Entra ID App Registration):
  - An Azure Service Principal is a security identity used by applications, services, and automation tools to access Azure resources like Power BI/Fabric.
  - It's kind of like a user account, but for automated processes that need to authenticate to Azure services without human intervention.
- Windows Task Scheduler:
  - A built-in Windows utility that allows users to schedule tasks to run at specific times or events.
  - You can use the Windows Task Scheduler to run Fabric Archive Bot automatically at regular intervals.

## Setting Up the Script (2:30–5:00)

- Show how to clone or download the repository.
- Open Export-FabricItemsFromAllWorkspaces.ps1 briefly, highlighting its parameters and their descriptions.
- Open Config.json, show where to place Tenant ID, App ID, and App Secret for the Azure Service Principal.
- Open IgnoreList.json, demonstrate how to ignore certain workspaces.
- Show the helpers folder and explain how to use Set-FabricArchiveBotUserEnvironmentVariable.ps1

## Running the Script (5:00–7:30)

- Demonstrate a PowerShell session.
- Explain the script's main flow:
  - Get configuration data from Config.json or environment variable.
  - Authenticate to Fabric
  - Retrieve workspace IDs
  - Loop through workspaces
  - Export items from each workspace
  - Save the exported items to the target folder in year/month/day subfolders
- Run the script manually and show the exported items appearing in the target folder.

## Scheduling with Windows Task Scheduler (7:30–9:00)

Demonstrate creating a basic task:
- Point the “Action” to PowerShell.exe.
- Pass script path as the “Argument.”
- Set daily or weekly triggers for automation.

## Conclusion (9:00–10:00)

Recap the process:
- Configure JSON.
- Run the script manually.
- Schedule it for automatic exports.
- Encourage viewers to contribute feedback and enhancements on GitHub.