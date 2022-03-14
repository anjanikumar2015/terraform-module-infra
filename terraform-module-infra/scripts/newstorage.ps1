param( 
    [Parameter(Mandatory=$true)] $rg_name,
    [Parameter(Mandatory=$true)] $location,
    [Parameter(Mandatory=$true)] $storage_name
    )
New-AzResourceGroup -Name $rg_name -Location $location -Force
$sa = New-AzStorageAccount -ResourceGroupName $rg_name `
    -AccountName $storage_name `
    -Location $location `
    -SkuName Standard_LRS `
    -AccessTier Cool `
    -AllowBlobPublicAccess $false `
    -EnableHttpsTrafficOnly $true `
    -MinimumTlsVersion TLS1_2
$saContext = $sa.Context
New-AzStorageContainer -Name "terraform" `
    -Context $saContext `
    -Permission Off