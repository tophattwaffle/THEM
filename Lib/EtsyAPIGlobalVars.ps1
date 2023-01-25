Write-Host "Loading GlobalVars..." -ForegroundColor Magenta

<#
These are variables that you can change to fit your needs.
#>
$global:dontRefreshOnLoad = $true
$global:DraftsOnly = $true
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
    "transactions_r"
)

<#
These variables are set in the script, and you should likely not change them here.
#>
$global:apiKey = $null
$global:codeChallenge = $null
$global:codeVerifier = $null
$global:state = $null
$global:allShops = New-Object Collections.Generic.List[Object]
