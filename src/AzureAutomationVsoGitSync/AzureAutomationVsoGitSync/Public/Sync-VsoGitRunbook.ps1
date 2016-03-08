	<#
	.SYNOPSIS 
		Syncs all runbooks in a VSO git repository to an Azure Automation account.

	.DESCRIPTION
		Syncs all runbooks in a VSO git repository to an Azure Automation account starting with dependent (child)
		runbooks and followed by parent runbooks to an existing Automation Account.  This runbook will recursively
		treat all sub directories within the VSORunbookFolderPath as dependent (child) runbooks and publish these 
		first
    
		Requires a VSO Alternate Authentication Credential for connecting with VSO-Git repository, stored 
		in a Automation credential asset.
    
		This runbook has a dependency on Azure-Connect, which you can download from 
		http://gallery.technet.microsoft.com/scriptcenter/Connect-to-an-Azure-f27a81bb
		The Azure-Connect runbook must be published for this runbook to run correctly
        
	.PARAMETER VSOCredentialName
		Name of the credential asset containing the VSO Alternate Authentication Credential name 
		and password configured from VSO Profile dialog.
    
	.PARAMETER VSOAccount
		Name of the account name for VSO Online.  Ex. https://accountname.visualstudio.com

	.PARAMETER VSOProject
		Name of the VSO project that contains the repository     

	.PARAMETER VSORepository
		Name of the repository that contains the runbook project

	.PARAMETER VSORunbookFolderPath
		Project path to the root where the runbooks are located.  Ex. /Project1/ProjectRoot
		where ProjectRoot contains the parent runbooks 

	.PARAMETER AutomationAccount
		Name of the Automation Account where the runbooks should be synced to

	.PARAMETER AzureConnectionName
		Name of the Azure connection asset that was created in the Automation service.
		This connection asset contains the subscription id and the name of the certificate 
		setting that holds the management certificate.
    
	.PARAMETER VSOBranch
		Optional name of the Git branch to retrieve the runbooks from.  Defaults to "master"

	.EXAMPLE
		Publish-From-GitVSO -VSOCredentialName "VSOCredentialAsset" -VSOAccount "AccountName" 
			-VSOProject "Project" -VSORepository "Repository" -VSORunbookFolderPath "/Project1/ProjectRoot" 
			-AutomationAccount "AccountName" -AzureConnectionName "ConnectionAssetName" -VSOBranch "master"

	#>
	function Sync-VsoGitRunbook
	{
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
			   [string] $TargetSubscriptionId,

			   [Parameter(Mandatory=$True)]
			   [string] $TargetAutomationAccount,

			   [Parameter(Mandatory=$True)]
			   [string] $TargetCredentialName,

			   [Parameter(Mandatory=$True)]
			   [string] $VSOBranch 
		)
    
		$psExtension = ".ps1"
		$grExtension = ".graphrunbook"
		$apiVersion = "1.0-preview"

		#Getting Credentail asset for VSO alternate authentication credentail
		$VSOCred = Get-AutomationPSCredential -Name $VSOCredentialName
		if ($VSOCred -eq $null)
		{
			throw "Could not retrieve '$VSOCredentialName' credential asset. Check that you created this asset in the Automation service."
		}    
		$VSOAuthUserName = $VSOCred.UserName
		$VSOAuthPassword = $VSOCred.GetNetworkCredential().Password
    
		#Creating authorization header using 
		$basicAuth = ("{0}:{1}" -f $VSOAuthUserName,$VSOAuthPassword)
		$basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
		$basicAuth = [System.Convert]::ToBase64String($basicAuth)
		$headers = @{Authorization=("Basic {0}" -f $basicAuth)}

		#ex. "https://gkeong.visualstudio.com/defaultcollection/_apis/git/automation-git-test2-proj/repositories/automation-git-test2-proj/items?scopepath=/Project1/Project1/&recursionlevel=full&includecontentmetadata=true&versionType=branch&version=production&api-version=1.0-preview"
		$VSOURL = "https://" + $VSOAccount + ".visualstudio.com/defaultcollection/_apis/git/" + 
				$VSOProject + "/repositories/" + $VSORepository + "/items?scopepath=" + $VSORunbookFolderPath +  
				"&recursionlevel=full&includecontentmetadata=true&versionType=branch&version=" + $VSOBranch +  
				"&api-version=" + $apiVersion
		Write-Verbose("Connecting to VSO using URL: $VSOURL")
		$results = Invoke-RestMethod -Uri $VSOURL -Method Get -Headers $headers
	
		$VerbosePreference = "Continue"
		#$results | ConvertTo-Json | Write-Verbose
	
		$allRunbooks = [AzureAutomationVsoGitSync.Models.SortedRunbookDictionary]@{}

		#grab folders & files
		$folderObj = @()
		foreach ($item in $results.value)
		{
			if ($item.gitObjectType -eq "tree")
			{
				$folderObj += $item
			}
			elseif (($item.gitObjectType -eq "blob") -and ($item.path -match $psExtension -or $item.path -match $grExtension))
			{
				# get runbook file name
				$path = $item.path; 
				$fileName = [AzureAutomationVsoGitSync.Models.Runbook]::GetRunbookFileName($path); 

				# local temp path for runbook
				$tempPath = Join-Path -Path $env:SystemDrive -ChildPath "temp"
				$outFile = Join-Path -Path $tempPath -ChildPath $fileName

				# download the runbook
				$fileUrl = $item.url
				Write-Verbose "`tGET $fileName"
				$VerbosePreference = "SilentlyContinue"
				Invoke-RestMethod -Uri $fileUrl -Method Get -Headers $headers -OutFile $outFile 
				$VerbosePreference = "Continue"

				$new = $allRunbooks.Add($outFile, $fileUrl)
			}
		}
	
		# Select the Azure Subscription
		$azCred = Get-AutomationPSCredential -Name $TargetCredentialName
		$azAcct = Add-AzureAccount -Credential $azCred
		$azSub = Select-AzureSubscription -SubscriptionId $TargetSubscriptionId

		#recursively go through most inner child folders first, then their parents, grand-parents, etc.
		for ($i = $folderObj.count - 1; $i -ge 0; $i--)
		{
			Write-Verbose("Processing files in $folderObj[$i]")        
			$folderURL = "https://" + $VSOAccount + ".visualstudio.com/defaultcollection/_apis/git/" + 
					$VSOProject + "/repositories/" + $VSORepository + "/items?scopepath=" + $folderObj[$i].path +  
					"&recursionLevel=OneLevel&includecontentmetadata=true&versionType=branch&version=" + 
					$VSOBranch + "&api-version=" + $apiVersion
                
			$results = Invoke-RestMethod -Uri $folderURL -Method Get -Headers $headers
        
			foreach ($item in $results.value)
			{
				$rb = $allRunbooks.FindByUrl($item.url)
				if ($rb -ne $null)
				{                
					$fileName = $rb.FileName
					$tempPath = Join-Path -Path $env:SystemDrive -ChildPath "temp"
					$outFile = Join-Path -Path $tempPath -ChildPath $fileName
					$runbookName = $rb.Name

					#Import ps1 files into Automation, create one if doesn't exist
					Write-Verbose("Importing runbook $runbookName into Automation Account...")
					$arb = Get-AzureAutomationRunbook -AutomationAccountName $TargetAutomationAccount -Name $runbookName -ErrorAction "SilentlyContinue"
					if ($arb -eq $null) 
					{ 
						Write-Verbose("`tRunbook $runbookName doesn't exist, creating it...") 
						New-AzureAutomationRunbook -AutomationAccountName $TargetAutomationAccount -Name $runbookName 
					}

					#Update the runbook, overwrite if existing 
					Write-Verbose("`tUpdating $runbookName ...") 
					Set-AzureAutomationRunbookDefinition -AutomationAccountName $TargetAutomationAccount -Name $runbookName -Path $Using:outFile -Overwrite 
                     
					#Publish the updated runbook 
					Write-Verbose("`tPublishing $runbookName ...")
					Publish-AzureAutomationRunbook -AutomationAccountName $TargetAutomationAccount -Name $runbookName 
                
				}
			}
		}
	}