# Video Script Outline

## Introduction (0:00–1:00)

- Greet viewers
  - “Hi, I’m James Bartlett, and today we’ll be exploring a free, open-source solution I developed called Fabric Archive Bot, and I'll show you how to automate backups of your Power BI and Fabric workspaces.”
  - “But first, I'd like to thank the Data Toboggan conference organizers for putting in the hard work to make this conference possible, and for giving me the opportunity to share this with you today.”
  - “In this demo, I’ll cover the key concepts behind Fabric Archive Bot, I'll show you how to set up the script, run it manually, and schedule it for automatic backups using Windows Task Scheduler. This tool is designed to work with Power BI and Fabric, but for the sake of time and simplicity, I'll refer to both as 'Fabric' from now on.”
- Mention prerequisites: 
  - Intermediate knowledge of the Fabric cloud service
  - Tenant administrator access to Fabric (or someone who can provide the necessary permissions)
  - An Azure Service Principal (Entra ID App Registration)
  - A Windows machine with PowerShell version 7+ and Windows Task Scheduler (or another scheduling tool that can run PowerShell scripts)

## Brief Overview of Key Concepts (1:00–2:30)

- REST API (Representational State Transfer Application Programming Interface):
  - Allows systems to communicate over HTTP using standard methods like GET and POST.
  - Fabric provides REST API endpoints for retrieving and managing resources.
- JSON (JavaScript Object Notation):
  - The format used by REST APIs to exchange data, commands, and configurations.
  - Fabric Archive Bot also reads config data (like credentials) from JSON files, such as Config.json.
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