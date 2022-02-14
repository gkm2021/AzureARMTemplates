<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
    [switch] $uploadscripts=$True,
    $subscriptionId="c8b41177-1dc8-47eb-af84-9c63b2bd6b71",
    $resourceGroupName ="parnasoftdevRG",
    $resourceGroupLocation = "centralindia",
    $vmName = "rootdc1",
    [Parameter(Mandatory=$True)]
    [string]$deploymentName,
    $templateFile = "azuredeploy.json",
    $parametersFile = "azuredeploy.parameters.json",
    $logfile="c:\temp\log.txt"
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    #Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
    Register-AzResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"
$parametersFilePath = $PSScriptRoot + "\" + $parametersFile
$workingdir = $PSScriptRoot
# sign in
Write-Host "Logging in...";
Clear-AzContext -Force;
Login-AzAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzSubscription -SubscriptionID $subscriptionId;
#Select-AzureRmSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.network","microsoft.compute","Microsoft.Resources","microsoft.storage");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else {
    Write-Host "Using existing resource group '$resourceGroupName'";
}

#get asset location and Sas Token for asset location
$storageAccountName = $resourceGroupName.ToLower() + "store"
Set-AzCurrentStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName

$context = $storageAccount.Context

$containerName = $workingdir.Substring($workingdir.LastIndexOf("\")+1)
$storageContainer = Get-AzStorageContainer -Name $containerName -Context $context -ErrorAction SilentlyContinue;
if ($null -eq $storageContainer) {
    New-AzStorageContainer -Name $containerName -Context $context -Permission Blob
    $storageContainer = Get-AzStorageContainer -Name $containerName -Context $context
}

$sasToken = New-AzStorageContainerSASToken -Name $containerName -Permission rw -ExpiryTime (Get-Date).AddHours(2.0);
$filetoUpdload = $workingdir + "\" +  $parametersFile
$replacewith = """sasToken"":{""value"":" + """$sasToken""}"
(Get-Content -path $filetoUpdload -Raw) -replace '"sasToken"(\s*):(\s*){(\s*)"value"(\s*):(\s*)"(.*)"(\s*)}',$replacewith | Set-Content -Path $filetoUpdload -Force
if ($uploadscripts){
    Get-ChildItem -File "$workingdir" -Recurse | Set-AzStorageBlobContent -Container $containerName -Context $context
}
else {
    Set-AzStorageBlobContent -Container $containerName -File $filetoUpdload -Force
}

$templateUrl = (Get-AzStorageBlob -Container $storageContainer.Name -Blob $templateFile).ICloudBlob.uri.AbsoluteUri;
$parameterUrl = (Get-AzStorageBlob -Container $storageContainer.Name -Blob $parametersFile).ICloudBlob.uri.AbsoluteUri;

# Start the deployment
Write-Host "Starting deployment...";
if(Test-Path $parametersFilePath) {
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateUri ($templateUrl + $sasToken) -sasToken $sasToken -TemplateParameterUri ($parameterUrl + $sasToken);
    #Test-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri ($templateUrl + $sasToken) -sasToken $sasToken -TemplateParameterUri ($parameterUrl + $sasToken);
} else { 
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateUri $templateUrl -artifactsLocationSasToken $sasToken;
}
Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status | Out-File $logfile