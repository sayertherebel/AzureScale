 <#
.SYNOPSIS
  Connects to Azure and vertically scales the VM

.DESCRIPTION
  This runbook connects to Azure and scales up the VM 

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
    [object]$ResourceGroupName
)


if ($VMName -ne "" -and $ResourceGroupName -ne "") {

	$noResize = "noresize"
		
	$scaleUp = @{
		"Standard_A0"      = "Standard_A1"
		"Standard_A1"      = "Standard_A2"
		"Standard_A2"      = "Standard_A3"
		"Standard_A3"      = "Standard_A4"
		"Standard_A4"      = $noResize
		"Standard_A5"      = "Standard_A6"
		"Standard_A6"      = "Standard_A7"
		"Standard_A7"      = $noResize
		"Standard_A8"      = "Standard_A9"
		"Standard_A9"      = $noResize
		"Standard_A10"     = "Standard_A11"
		"Standard_A11"     = $noResize
		"Basic_A0"         = "Basic_A1"
		"Basic_A1"         = "Basic_A2"
		"Basic_A2"         = "Basic_A3"
		"Basic_A3"         = "Basic_A4"
		"Basic_A4"         = $noResize
		"Standard_D1_v2"   = "Standard_D2_v2"
		"Standard_D2_v2"   = "Standard_D3_v2"
		"Standard_D3_v2"   = "Standard_D4_v2"
		"Standard_D4_v2"   = "Standard_D5_v2"
		"Standard_D5_v2"   = $noResize
		"Standard_D11_v2"  = "Standard_D12_v2"
		"Standard_D12_v2"  = "Standard_D13_v2"
		"Standard_D13_v2"  = "Standard_D14_v2"
		"Standard_D14_v2"  = $noResize
		"Standard_DS1"     = "Standard_DS2"
		"Standard_DS2"     = "Standard_DS3"
		"Standard_DS3"     = "Standard_DS4"
		"Standard_DS4"     = $noResize
		"Standard_DS11"    = "Standard_DS12"
		"Standard_DS12"    = "Standard_DS13"
		"Standard_DS13"    = "Standard_DS14"
		"Standard_DS14"    = $noResize
		"Standard_D1"      = "Standard_D2" 
		"Standard_D2"      = "Standard_D3"
		"Standard_D3"      = "Standard_D4"
		"Standard_D4"      = $noResize
		"Standard_D11"     = "Standard_D12"
		"Standard_D12"     = "Standard_D13"
		"Standard_D13"     = "Standard_D14"
		"Standard_D14"     = $noResize
		"Standard_G1"      = "Standard_G2" 
		"Standard_G2"      = "Standard_G3"
		"Standard_G3"      = "Standard_G4" 
		"Standard_G4"      = "Standard_G5"  
		"Standard_G5"      = $noResize
		"Standard_GS1"     = "Standard_GS2" 
		"Standard_GS2"     = "Standard_GS3"
		"Standard_GS3"     = "Standard_GS4"
		"Standard_GS4"     = "Standard_GS5"
		"Standard_GS5"     = $noResize
	}
		
	# Connect to Azure and select the subscription to work against
	# $Cred = Get-AutomationPSCredential -Name 'AzureCredential'
	# $null = Add-AzureRmAccount -Credential $Cred -ErrorAction Stop
		
	# $SubId = Get-AutomationVariable -Name 'AzureSubscriptionId'
	# $null = Set-AzureRmContext -SubscriptionId $SubId -ErrorAction Stop

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

	$null = $vm.Tags.TryGetValue("SCALEUP", [ref] $tag)

	# If the SCALEUP tag has value 'TRUE' proceed, otherwise exit

	if ($tag -eq "TRUE")
	{

		$currentVMSize = $vm.HardwareProfile.vmSize
		
		Write-Output "`nFound the specified Virtual Machine: $VmName"
		Write-Output "Current size: $currentVMSize"
		
		$newVMSize = ""
		
		$newVMSize = $scaleUp[$currentVMSize]
		
		if($newVMSize -eq $noResize) {
			Write-Output "Sorry the current Virtual Machine size $currentVMSize can't be scaled $scaleAction. You'll need to recreate the specified Virtual Machine with your requested size"
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
	else
	{
		Write-Output "SCALEUP tag not present."
		exit
	}

}
else {
	Write-Output "Required parameter not supplied."
	exit
}
