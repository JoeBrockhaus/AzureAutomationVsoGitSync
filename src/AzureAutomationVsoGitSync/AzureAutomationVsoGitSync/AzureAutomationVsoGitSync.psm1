
	#Get public and private function definition files.
    $Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
    $Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

	#Dot source the files
    Foreach($import in @($Public + $Private))
    {
        Try
        {
            . $import.fullname
        }
        Catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }

	$VerbosePreference = "Continue"
	
	foreach($member in $Public)
	{
		try{
			Export-ModuleMember -Function $member.Basename -Verbose
		} catch { Write-Error $_; Write-verbose "failed $_" }
	}

	$VerbosePreference = "SilentlyContinue"
