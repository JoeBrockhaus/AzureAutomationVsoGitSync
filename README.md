# AzureAutomationVsoGitSync
AzureAutomationVsoGitSync is a tool to make Continuous Delivery of the Azure Automation runbooks from VSO-Git as straightforward as possible.
All runbooks from the specified folder in a VSO-Git repository to an existing Azure Automation Account. 
Once the Runbooks are downloaded from the repository, they are inspected for references to other Runbooks from the set being synced.
The Runbooks are then topologically sorted by those dependencies and published in that order.   

This tool was inspired by the lack of well-rounded official tooling & the shortcomings of Sync-VsoGitRunbook (which I don't think was ever actually completed). 
Unlike the latter, this tool avoids the issue of having to use obtuse folder structures and needing to manually manage dependencies. 
Avoiding that folder structure also allows you to use the Azure Automation PowerShell ISE Add-On for development and testing, as well as managing the rest of the Assets that the Add-On supports.
Ideally this tool could evolve to publish those assets, and more, as well.

<br>
*[Import the Module into your Automation Account from PowerShell Gallery](https://www.powershellgallery.com/packages/AzureAutomationVsoGitSync)* 
<br>
##Basics

### There are 4 main components
1. C# Models & Assembly
2. PowerShell cmdlets for deploying to both ASM & ARM Automation Accounts
3. PowerShell Module containing the assembly & cmdlets.
4. Sample PowerShell runbook to invoke the tool. 


### Requirements
1. VSO Git repository containing Azure Automation runbooks (.ps1 or .graphrunbook).
2. VSO Alternate Authentication Credential for connecting to VSO-Git repository, configured from VSO dashboard (from "My Profile"). 
3. Automation Credential Asset containing the VSO Alternate Credentials.
4. Automation Account where the runbooks will be published.
5. Azure User Credential for publishing to the target Automation Account.
6. Automation Credential Asset containing Azure User Credential. 

### Samples
1. Sync-AzureRMRunbooks.ps1
    - Syncs runbooks to a v2 Automation Account 
2. Sync-AzureSMRunbooks.ps1
    - Syncs runbooks to a v1 Automation Account
<br>
    
## Configuring Integration - Webhooks

### VSO Steps
1. Your runbook will need to be invoked when events occur in VSO. For instance: On Code Pushed 
2. VSO allows a webhook to be triggered on these events. 
3. Navigate to your VSO Service Hooks admin configuration. ie: http://vsoAccountName.visualstudio.come/DefaultCollection/teamProjectName/_admin/_servicehooks
4. Click [+] to add a new Service Hook
5. Scroll the list of Services, select 'Web Hooks' then click [Next]. 
6. Configure the filters as appropriate for your sync strategy then click [Next].
7. Follow the Azure Automation Steps 1-6 below
8. No other data is required, however you may choose to send custom headers or modify the data sent in the Body of the request.

### Azure Automation Steps
1. Navigate to your collection of Runbooks Automation Account in the Portal. 
2. If you haven't already, import the sample Runbooks and Publish them.
<br>It's a good idea to turn on Verbose logging for the runbook(s) - at least initially.
3. Select the appropriate runbook, then open its [Webhooks] Blade by clicking that Tile. 
4. Click [+] to open the New Webhook Blade, then 'Create new webhook'
5. Give the webhook a meaningful name - one that aligns with the filters you configured in VSO.
6. BEFORE CLICKING OK, make sure you copy the Webhook URL. 
7. Paste the WebHook URL into the URL field of the Service Hook - Action config screen in VSO.
8. Now click [OK] and then 'Configure parameters and run settings' 
9. Enter all the relevant configuration data, being sure to align with the name of your WebHook & the filters for the VSO Service Hook. 
10. Click [OK], then [Create] and your webhook will be provisioned. 

## Testing
Once you've created the VSO Service & Runbook Web Hooks, you are now ready to start testing. 

VSO provides a handy [Test] button on the New Service Hook window, which will light up once you drop in your WebHook URL. 
<br>Click it! Once the request is sent, you can pop back over to your Automation Account's Jobs Blade and you should see a job Kicked off with the parameters you specified on the WebHook, as well as the JSON-formatted WebHookData object from VSO with all the relevant details you chose to include in the POST data. 

That's it!

## Contributing
I have a lot of ideas for this project, but as I'm not sure how much time I'll actually have to spend on it, any input is gladly welcomed! 

The Azure Automation team has been working on VSO integration for some time now, and once that is completed this may prove to be less useful. 

In addition, there are still lots of pieces missing from this that require syncing to the Automation Accounts: All the Asset types, webhooks, etc. 
In all reality, ARM templates are likely a better route forward. Base templates can be found [here](https://github.com/azureautomation/automation-packs/tree/master/000-base-automation-resource-templates) and any further work in automating those other assets will likely come in that form. 

For deploying these ancillary assets in the meantime, I'd suggest the combination of the [PowerShell ISE Preview](https://blogs.msdn.microsoft.com/powershell/2016/01/20/introducing-the-windows-powershell-ise-preview/) and the [Azure Automation PowerShell ISE Add-On](https://azure.microsoft.com/en-us/blog/announcing-azure-automation-powershell-ise-add-on/). You still cannot deploy modules or manage webhooks, but it's great for Assets & bulk actions. Plus it's open source!  
