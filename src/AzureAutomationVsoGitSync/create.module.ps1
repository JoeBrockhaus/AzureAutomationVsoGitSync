
$outDir = $args[0];

# import the filesystem assembly
Add-Type -Assembly "System.IO.Compression.FileSystem" ;

$outMod = "$($outDir)_Module\"
# delete any existing module output
Remove-Item "$outMod\*.*" -Recurse -Force
# force-create directory
#New-Item $outMod -ItemType Directory -Force

$mods = @(
	@{ 
		dir = "$($outDir)AzureAutomationVsoGitSync"; 
		out = "$($outMod)AzureAutomationVsoGitSync.zip"; 
		dllDepends = @( "$($outDir)Newtonsoft.Json.dll",
						"$($outDir)Orchestrator.GraphRunbook.Model.dll"
						"$($outDir)AzureAutomationVsoGitSync.dll"
						);
	}
)

""
"Creating Modules..."

foreach ($mod in $mods) {
	$modName = $($mod.dir -split "\\")[-1]

	$loadLib = ($mod.dllDepends -ne $null -and $mod.dllDepends.count -gt 0)
	if ($loadLib)
	{
		Write-Host "`t$modName... " 
		Write-Host "`t`t|-lib\"
		$libPath = "$($mod.dir)\lib\"
		md "$libPath" -Force | Out-Null
		foreach($dll in $mod.dllDepends)
		{
			Write-Host "`t`t|`t$dll... " -NoNewline
			Copy-Item $dll $libPath 
			Write-Host "Done."
		}

		Write-Host "`t.zip... "  -NoNewline
	}
	else
	{
		Write-Host "`t$modName.zip... " -NoNewline 
	}

	[System.IO.Compression.ZipFile]::CreateFromDirectory($mod.dir, $mod.out, `
		[System.IO.Compression.CompressionLevel]::Optimal, $true);

	Write-Host "`tDone."
}

""
