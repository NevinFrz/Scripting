# ###################################################################
# Merge JSON Confguration Files
# ###################################################################

function Get-RequiredParam($Name) {
    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue    
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    if ($result -eq $null) {
		throw "Missing parameter value $Name"
    }

    return $result
}

function Merge-Objects($file1, $file2) {
    $propertyNames = $($file2 | Get-Member -MemberType *Property).Name
    foreach ($propertyName in $propertyNames) {
		# Check if property already exists
        if ($file1.PSObject.Properties.Match($propertyName).Count) {
            if ($file1.$propertyName.GetType().Name -eq 'PSCustomObject') {
				# Recursively merge subproperties
                $file1.$propertyName = Merge-Objects $file1.$propertyName $file2.$propertyName
            } else {
				# Overwrite Property
                $file1.$propertyName = $file2.$propertyName
            }
        } else {
			# Add property
            $file1 | Add-Member -MemberType NoteProperty -Name $propertyName -Value $file2.$propertyName
        }
    }
    return $file1
}

function Merge-Json($sourcePath, $transformPath, $failIfTransformMissing, $outputPath) {
	if(!(Test-Path $sourcePath)) {
		Write-Host "Source file $sourcePath does not exist!"
		Exit 1
	}
	
	$sourceObject = (Get-Content $sourcePath) -join "`n" | ConvertFrom-Json
	$mergedObject = $sourceObject
	
	if (!(Test-Path $transformPath)) {
		Write-Host "Transform file $transformPath does not exist!"
		if ([System.Convert]::ToBoolean($failIfTransformMissing)) {
			Exit 1
		}
		Write-Host 'Source file will be written to output without changes'
	} else {
		Write-Host 'Applying transformations'
		$transformObject = (Get-Content $transformPath) -join "`n" | ConvertFrom-Json
		$mergedObject = Merge-Objects $sourceObject $transformObject
	}
	
	Write-Host "Writing merged JSON to $outputPath.."
	$mergedJson = $mergedObject | ConvertTo-Json -Depth 100
	[System.IO.File]::WriteAllLines($outputPath, $mergedJson)
}

$ErrorActionPreference = 'Stop'

if($OctopusParameters -eq $null) {
    Write-Host 'OctopusParameters is null...exiting with 1'
    Exit 1    
}
$StepName = $OctopusParameters['Octopus.Step.Name']
$InstallationDirPath = $OctopusParameters["Octopus.Action[" + $StepName + "].Output.Package.InstallationDirectoryPath"] + "\"
$DestFilePath = $InstallationDirPath + $OctopusParameters['JSONMergeToFile']
$SourceFilePath = $InstallationDirPath + $OctopusParameters['JSONMergeFromFile']
$FailIfTransformFileMissing = Get-RequiredParam 'FailIfSourceFileMissing'
$OutputFilePath = $DestFilePath
$JSONMergeEnabled = Get-RequiredParam 'EnableJSONMerging'

if ($JSONMergeEnabled) {
    Write-Host 'Starting JSON Merge'
    Merge-Json $DestFilePath $SourceFilePath $FailIfTransformFileMissing $OutputFilePath
} else {
    Write-Host 'JSON merge disabled in settings. Hence skipping JSON merge.'
}




# Get-Service doesn't return much information
# This will return all info about the service including the full path which we can use to uninstall it
function Find-Service
{
    param
    (
        $Name = ''
    )
    $pattern = '^.*\.exe\b'

    $Name = $Name.Replace('*','%')

    Get-WmiObject -Class Win32_Service -Filter "Name = '$Name'"|
      ForEach-Object {

        if ($_.PathName -match $pattern)
        {
            $Path = $matches[0].Trim('"')
            $file = Get-Item -Path $Path
            $rv = $_ | Select-Object -Property Name, DisplayName, isMicrosoft, Started, StartMode, Description, CompanyName, ProductName, FileDescription, ServiceType, ExitCode, InstallDate, DesktopInteract, ErrorControl, ExecutablePath, PathName
            $rv.CompanyName = $file.VersionInfo.CompanyName
            $rv.ProductName = $file.VersionInfo.ProductName
            $rv.FileDescription = $file.VersionInfo.FileDescription
            $rv.ExecutablePath = $path
            $rv.isMicrosoft = $file.VersionInfo.CompanyName -like '*Microsoft*'
            $rv
        }
        #else
        #{
        #    Write-Warning ("Service {0} has no EXE attached. PathName='{1}'" -f $_.PathName)
        #}
      }
 }
$NumberOfInstances=$OctopusParameters["NumberOfInstances"]
$ServiceName = $OctopusParameters["ServiceName"]
$DisplayName = $OctopusParameters["DisplayName"]
$ServiceDescription = $OctopusParameters["ServiceDescription"]
$InstanceName = $OctopusParameters["InstanceName"]
$StartupType = $OctopusParameters["StartupType"]
$ServiceLogonType = $OctopusParameters["ServiceLogonType"]
$UserName = $OctopusParameters["UserName"]
$Password = $OctopusParameters["Password"]
$StepName = $OctopusParameters['Octopus.Step.Name']
$ExecutablePath = $OctopusParameters["Octopus.Action[" + $StepName + "].Output.Package.InstallationDirectoryPath"] + "\" + $OctopusParameters["ExecutablePath"]
for ($i=0; $i -lt $NumberOfInstances; $i++) {

 # ###################################################################
# Configure the installation arguments
# ###################################################################
$InstallArguments = @("install")

# Name parameters
if (![string]::IsNullOrEmpty($ServiceName)) {
    $InstallArguments += ,"-servicename"
	if ($NumberOfInstances -gt 1) {
	$InstServiceName="$ServiceName$i"
	}else{
	$InstServiceName="$ServiceName"
	}	
    $InstallArguments += """$InstServiceName"""
}
if (![string]::IsNullOrEmpty($DisplayName)) {
    $InstallArguments += ,"-displayname"
	$InstDisplayName =$DisplayName + "#" + $i
    $InstallArguments += """$InstDisplayName"""
}
if (![string]::IsNullOrEmpty($ServiceDescription)) {
    $InstallArguments += ,"-description"
    $InstallArguments += ,"""$ServiceDescription"""
}
if (![string]::IsNullOrEmpty($InstanceName)) {
    $InstallArguments += ,"-instance"
    $InstallArguments += ,"""$InstanceName"""
}

if (![string]::IsNullOrEmpty($StartupType)) {
    switch($StartupType.ToLower())
    {
        "automatic" {$InstallArguments += ,"--autostart"}
        "automaticdelayed" {$InstallArguments += ,"--delayed"}
        "manual" {$InstallArguments += ,"--manual"}
        "disabled" {$InstallArguments += ,"--disabled"}
    }
}

if (![string]::IsNullOrEmpty($ServiceLogonType)) {
    switch ($ServiceLogonType.ToLower())
    {
        "localsystem" {$InstallArguments += ,"--localsystem"}
        "localservice" {$InstallArguments += ,"--localservice"}
        "networkservice" {$InstallArguments += ,"--networkservice"}
		
        "username" {
            $InstallArguments += ,"-username"
            $InstallArguments += ,"""$UserName"""
            $InstallArguments += ,"-password"
            $InstallArguments += ,"""$Password"""
        }
    }
}

#  ##################################################################
# Install and start the service
# ###################################################################


Write-Host "Executing install command: $ExecutablePath $InstallArguments"
& $ExecutablePath $InstallArguments

if (![string]::IsNullOrEmpty($InstanceName)) {
    Write-Host "Starting Service: $InstServiceName$$InstanceName"
	$InstServiceName = $InstServiceName + "$" + $InstanceName	
} else {

	Write-Host "Starting Service: $InstServiceName"

}
Start-Service -Name $InstServiceName


}