
	[CmdletBinding()]	
	param (			   
		[Parameter(Mandatory=$True)]
		[string] $VSOCredentialName,

		[Parameter(Mandatory=$True)]
		[string] $VSOAccount,

		[Parameter(Mandatory=$True)]
		[string] $VSOProject,

		[Parameter(Mandatory=$True)]
		[string] $VSORepository,

		[Parameter(Mandatory=$True)]
		[string] $VSORunbookFolderPath,
       
		[Parameter(Mandatory=$True)]
		[string] $TargetResourceGroup,

		[Parameter(Mandatory=$True)]
		[string] $TargetAutomationAccount,

		[Parameter(Mandatory=$True)]
		[string] $VSOBranch,

		[Parameter(Mandatory=$False)]
		[bool] $FlatFilesMode = $True, 
		     
		[Parameter(Mandatory=$False)]
		[object]$WebhookData
	)
		
	$VerbosePreference = "Continue" 
			
	# If runbook was called from Webhook, WebhookData will not be null.
	if ($WebhookData -ne $null) 
	{	
	    # Collect properties of WebhookData
	    $WebhookName    =   $WebhookData.WebhookName
	    $WebhookHeaders =   $WebhookData.RequestHeader
	    $WebhookBody    =   $WebhookData.RequestBody
	}
    
	if ((Get-Module "AzureAutomationVsoGitSync") -eq $null)
	{
		Write-Verbose "Importing AzureAutomationVsoGitSync..." 
		$VerbosePreference = "SilentlyContinue"
		Import-Module "AzureAutomationVsoGitSync"
		$VerbosePreference = "Continue" 
	}
		
    $PSBoundParameters.FlatFilesMode = $FlatFilesMode
	if($PSBoundParameters.ContainsKey("WebhookData")){ $PSBoundParameters.Remove("WebhookData") }
    $PSBoundParameters | ConvertTo-Json | Write-Verbose
	Sync-VsoGitRmRunbooks @PSBoundParameters