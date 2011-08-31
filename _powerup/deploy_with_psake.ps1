param([string]$deployFile = ".\deploy.ps1", [string]$deploymentEnvironment, [bool]$onlyFinalisePackage=$false, $tasks="default")

function OverlayEnvironmentSpecificFiles($deploymentEnvironment)
{
	$currentPath = Get-Location

	if ((Test-Path $currentPath\_environments\$deploymentEnvironment -PathType Container) -eq $true)
	{
		Copy-Item $currentPath\_environments\$deploymentEnvironment\* -destination $currentPath\ -recurse -force   
	}	
}

function OverlayTemplatedFiles($settings, $deploymentEnvironment)
{
	$currentPath = Get-Location
	
	if ((Test-Path $currentPath\_templates\ -PathType Container) -eq $false)
	{
		return
	}

	copy-substitutedsettingfiles -templatesDirectory $currentPath\_templates -targetDirectory $currentPath\_templatesoutput -deploymentEnvironment $deploymentEnvironment -settings $settings
	
	if ((Test-Path $currentPath\_templatesoutput\$deploymentEnvironment -PathType Container) -eq $true)
	{
		Copy-Item $currentPath\_templatesoutput\$deploymentEnvironment\* -destination $currentPath\ -recurse -force    
	}
}

function CheckForCorrectDeploymentServer($expectedComputerName)
{
	$currentComputerName = gc env:computername
	
	if (!($expectedComputerName.ToLower().Contains("localhost")) -and !($expectedComputerName.ToLower().Contains($currentComputerName.ToLower())))
	{
		throw "Deployment halted, as it is being run against incorrect deployment server"
	}
}

try {
	$ErrorActionPreference='Stop'
	$currentPath = Get-Location

	echo "Deploying package onto environment $deploymentEnvironment"	
	echo "Deployment being run under account $env:username"
	echo "Importing basic modules required by PowerUp"
	$env:PSModulePath = $env:PSModulePath + ";$currentPath\_powerup\modules\"
	import-module psake.psm1
	import-module AffinityId\Id.PowershellExtensions.dll
	import-module powerupremote
	

	echo "Copying files specific to this environment to necessary folders within the package"
	OverlayEnvironmentSpecificFiles $deploymentEnvironment

	echo "Reading settings"		
	$settings = get-parsedsettings $currentPath\settings.txt $deploymentEnvironment 
	$settings['deployment.environment'] = $deploymentEnvironment 
	
	echo "Package settings for this environment are:"
	$settings | Format-Table -property *
	
	echo "Substituting and copying templated files"	
	OverlayTemplatedFiles $settings $deploymentEnvironment
		
	if (!$onlyFinalisePackage)
	{		
		echo "Calling psake package deployment script"
		$psake.use_exit_on_error = $true
		invoke-psake $deployFile $tasks –parameters $settings
	}
}
finally {
try{
		remove-module psake
		remove-module Id.PowershellExtensions
		}
catch{}
}
