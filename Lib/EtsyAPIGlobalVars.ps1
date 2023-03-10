Write-Host "Loading GlobalVars..." -ForegroundColor Magenta

<#
These are variables that you can change to fit your needs.
#>
$global:dontRefreshOnLoad = $false
$global:DraftsOnly = $false
$global:redirectURL = "https://www.tophattwaffle.com/auth.php"
$global:saveLocation = "$([Environment]::GetFolderPath("MyDocuments"))\EtsyAPI"

<#
These are the scopes the script needs to talk to Etsy. You can edit them if you want.
Changing them will likely break part of the script.
#>
$global:scopes = @(
    "listings_r",
    "listings_w",
    "shops_r",
    "shops_w",
    "billing_r",
    "transactions_r",
    "profile_r"
)

<#
These variables are set in the script, and you should likely not change them here.
#>
$global:codeChallenge = $null
$global:codeVerifier = $null
$global:state = $null
$global:allShops = New-Object Collections.Generic.List[Object]

$global:settings = @{
    apiKey = $null
    webhookUrl = $null
    splitChar = ';'
    csvVariationLimit = 30
    shopImageAltText = "Shop Informational Image"
}