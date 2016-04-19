 <#
.SYNOPSIS
  Connects to Azure and vertically scales the VM

.DESCRIPTION
  This runbook connects to Azure and scales the passed VM either up or down based on the presence of a tag

  REQUIRED AUTOMATION ASSETS
  1. An Automation variable asset called "AzureSubscriptionId" that contains the GUID for this Azure subscription of the VM.  
  2. An Automation credential asset called "AzureCredential" that contains the Azure AD user credential with authorization for this subscription. 

.PARAMETER VMName
   Required 
   This is the name of the VM to scale

.PARAMETER ResourceGroupName
   Required 
   This is the name of the resource group that contains the VM

.NOTES
   AUTHOR: Jamie Sayer, based on a Azure Compute Team sample
   LASTEDIT: 19/04/2016
#>

param (
	[parameter(Mandatory = $true)]
    [object]$VMName,
	[parameter(Mandatory = $true)]
    [object]$ResourceGroupName,
	[parameter(Mandatory = $true)]
    [object]$OffPeakSize,
	[parameter(Mandatory = $true)]
    [object]$PeakSize
)


if ($VMName -ne "" -and $ResourceGroupName -ne "") {

	$connectionName = "AzureRunAsConnection"
	try
	{
		# Get the connection "AzureRunAsConnection "
		$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

		"Logging in to Azure..."
		Add-AzureRmAccount `
			-ServicePrincipal `
			-TenantId $servicePrincipalConnection.TenantId `
			-ApplicationId $servicePrincipalConnection.ApplicationId `
			-CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
	}
	catch {
		if (!$servicePrincipalConnection)
		{
			$ErrorMessage = "Connection $connectionName not found."
			throw $ErrorMessage
		} else{
			Write-Error -Message $_.Exception
			throw $_.Exception
		}
	}
		
	try {
		$vm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -VMName $VmName -ErrorAction Stop
	} catch {
		Write-Error "Virtual Machine not found"
		exit
	}

	# Get SCALEUP tag

	[string]$tag

	$null = $vm.Tags.TryGetValue("SCALE", [ref] $tag)

	# If the SCALEUP tag has value 'TRUE' proceed, otherwise exit

	if ($tag -eq "PEAK")
	{
		$newVMSize = $PeakSize
		}
	else
	{
		$newVMSize = $OffPeakSize
	}
		$currentVMSize = $vm.HardwareProfile.vmSize
		
		Write-Output "`nFound the specified Virtual Machine: $VmName"
		Write-Output "Current size: $currentVMSize"
		
		$newVMSize = $PeakSize
		
		if($newVMSize -eq $currentVMSize) {
			Write-Output "The Virtual Machine is already correctly scaled. "
		} 
		else
		{
			Write-Output "`nNew size will be: $newVMSize"
				
			$vm.HardwareProfile.VmSize = $newVMSize
			Update-AzureRmVm -VM $vm -ResourceGroupName $ResourceGroupName
			
			$updatedVm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -VMName $VmName
			$updatedVMSize = $updatedVm.HardwareProfile.vmSize
			
			Write-Output "`nSize updated to: $updatedVMSize"	

		}
}
else {
	Write-Output "Required parameter not supplied."
	exit
}
