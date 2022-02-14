param()

$dir = $PSScriptRoot
#The name of the Blob container to be created.  Typically this is the lsat folder in $dir
$containerName = $dir.Substring($dir.LastIndexOf("\")+1)

# $subscriptionId = Read-Host -Prompt "Enter subscriptionID"
# $resourcegroupName = Read-Host -Prompt "Enter a resourcegroup name"   # This name is used to generate names for Azure resources, such as storage account name.
# $location = Read-Host -Prompt "Enter a location (i.e. eastus)"

$subscriptionId = "c8b41177-1dc8-47eb-af84-9c63b2bd6b71"
$resourcegroupName = "parnasoftdevRG"
$location = "centralindia"

# sign in
Write-Host "Logging in...";
Clear-AzContext -Force
Login-AzAccount;

Write-Host "Selecting subscription '$subscriptionId'";
Select-AzSubscription -SubscriptionID $subscriptionId;

$storageAccountName = $resourceGroupName.ToLower() + "store"

# Create a resource group
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -Location $location -ErrorAction SilentlyContinue
if ($null -eq $resourceGroup){
    New-AzResourceGroup -Name $resourceGroupName -Location $location
}

# Create a storage account
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName  -ErrorAction SilentlyContinue
if ($null -eq $storageAccount) {
    $storageAccount = New-AzStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -Location $location `
    -SkuName "Standard_LRS"
}

$context = $storageAccount.Context

# Create a container
$storageContainer = Get-AzStorageContainer -Name $containerName -Context $context -ErrorAction SilentlyContinue
if ($null -eq $storageContainer) {
    New-AzStorageContainer -Name $containerName -Context $context
}

#Get-ChildItem -File "$dir" -Recurse | Set-AzStorageBlobContent -Container $containerName -Context $context