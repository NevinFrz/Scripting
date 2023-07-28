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

$sourceFilePath = Get-RequiredParam 'jmf_SourceFile'
$transformFilePath = Get-RequiredParam 'jmf_TransformFile'
$failIfTransformFileMissing = Get-RequiredParam 'jmf_FailIfTransformFileMissing'
$outputFilePath = Get-RequiredParam 'jmf_OutputFile'

Merge-Json $sourceFilePath $transformFilePath $failIfTransformFileMissing $outputFilePath

# #### Restat componet#######
Start-Sleep -seconds 5
$ComponentType =$OctopusParameters["ComponentType"]
$ItemName =$OctopusParameters["ItemName"]
$NumberOfInstances=$OctopusParameters["NumberOfInstances"]
$InstanceName =$OctopusParameters["InstanceName"]
Write-Host "$NumberOfInstances"
Write-Host "$ComponentType"
Write-Host "ItemName is $ItemName"
if (![string]::IsNullOrEmpty($ComponentType)) {
    switch($ComponentType.ToLower())
    {
        "web api" {
        	Restart-WebAppPool $ItemName
            Write-Host "Restarted $ItemName"
            }
        "windows service" {
							for ($i=0; $i -lt $NumberOfInstances; $i++) {
									if ($NumberOfInstances -gt 1) {
									$ServiceInstanceName = $ItemName + $i +"$"+ $InstanceName
									}else{
									$ServiceInstanceName = $ItemName +"$"+ $InstanceName
									}
									#$StopServiceInstanceName ="$"+ $ServiceInstanceName
									Write-Host "Restarting service " + $ServiceInstanceName
									Restart-Service -Name $ServiceInstanceName
								}
							}
    }
}