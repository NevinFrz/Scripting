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
# Stop the service and uninstall it if it exists
# ###################################################################
	if ($NumberOfInstances -gt 1) {
	$ServiceInstanceName = $ServiceName + $i +"$"+ $InstanceName
	}else{
	$ServiceInstanceName = $ServiceName +"$"+ $InstanceName
	}
	#$StopServiceInstanceName ="$"+ $ServiceInstanceName
	Write-Host "Checking for service " + $ServiceInstanceName
	$svcpid = (get-wmiobject Win32_Service | where{$_.Name -eq $ServiceInstanceName}).ProcessId
	Write-Host "Found PID " + $svcpid 
	if (($svcpid  -or $svcpid -gt 0)) {
	Write-Host "Stopping " + $svcpid 
	Stop-Process -ID $svcpid -Force
	Start-Sleep -seconds 5
	$ServiceInstanceStatus = Get-Service -name $ServiceInstanceName | Select -Property Status
	if($ServiceInstanceStatus -ne "Stopped"){	Start-Sleep -seconds 5 }
	Write-Host "Service status " + $ServiceInstanceStatus
}
# ###################################################################
# Service uninstall
# ###################################################################
		
	#Write-Host "ExecutablePath value : $ExecutablePath"
	 #$UninstallPath = $ExecutablePath
	# Prefer using the current running service executable to uninstall the service. If it can't be found fall back to the one we are installing with.
		
		 $CurrentServiceInstance = Find-Service $ServiceInstanceName -ErrorAction SilentlyContinue
		Write-Host "CurrentServiceInstance value : $CurrentServiceInstance"
		 if ($CurrentServiceInstance -and ![string]::IsNullOrEmpty($CurrentServiceInstance.ExecutablePath)) {
			 $UninstallPath = $CurrentServiceInstance.ExecutablePath
			 Write-Host "Successfully found the previous installation at ""$UninstallPath"". I will uninstall the service using that."
			 #$UninstallArguments =$UninstallArguments + $i
		 $UninstallArguments  = @("uninstall")
		 Write-Host "UninstallPath value: $UninstallPath"
		 Write-Host "UninstallArguments value: $UninstallPath $UninstallArguments"
		   if (![string]::IsNullOrEmpty($ServiceName)) {
				$UninstallArguments += ,"-servicename"
				if($NumberOfInstances -gt 1){
				$UninstallArguments += $ServiceName + $i#'"'+$ServiceName''+$i'"' #'"+ $ServiceName + $i"'
				}else
				{$UninstallArguments += $ServiceName}
		   }
		   if (![string]::IsNullOrEmpty($InstanceName)) {
				$UninstallArguments += ,"-instance"
				$UninstallArguments += ,"""$InstanceName"""
		   }
		
		   Write-Host "Executing uninstall command: $UninstallPath $UninstallArguments"
		   $UninstallResult = & $UninstallPath $UninstallArguments
		 } else {
			 $UninstallResult = "Could not find the previous installation."
		 }

		  
		   Write-Host $UninstallResult
}