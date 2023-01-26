Write-Host "Loading THEMFunctions..." -ForegroundColor Magenta

<#
Main menu function.
#>
function MainMenu() {
    $RefreshAllShops = New-Object System.Management.Automation.Host.ChoiceDescription '&Refresh Shop Data', 'Asks for new shop data from Etsy'
    $AddShop = New-Object System.Management.Automation.Host.ChoiceDescription '&Add New Shop', 'Adds a new shop to be managed by this application'
    $ExportListings = New-Object System.Management.Automation.Host.ChoiceDescription '&Export Listings', 'Exports listings to a CSV file'
    $UpdateVariations = New-Object System.Management.Automation.Host.ChoiceDescription '&Update Variations', 'Updates variations based on CSV files previous exported'

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($RefreshAllShops, $AddShop, $ExportListings, $UpdateVariations)
    $title = 'What would you like to do?'
    $message = 'Please make a selection for what you would like to do...'
    $choice = $host.ui.PromptForChoice($title, $message, $options, 0)
    switch ($choice) {
        0 { RefreshAllShops }
        1 { AddShop }
        2 { ExportListings }
        3 { UpdateVariations }
    }
}

<#
Updates all loaded shops from Etsy.
#>
function UpdateShopFromEtsy($shop) {
    Write-host "Getting shop information for $($shop.shop_name)..." -ForegroundColor Cyan
    $shop.openOrders = GetAllOpenOrders $shop.shop_id $shop.accessToken
    $shop.allListings = GetAllListings $shop.shop_id $shop.accessToken

    Write-host "`t[$($shop.openOrders.count)] open orders." -ForegroundColor Cyan
    Write-host "`t[$($shop.allListings.count)] active listings listings." -ForegroundColor Cyan
}

<#
Gets the shop data from Etsy.
Then creates a new shop object in the script.
#>
function CreateShop($OAuthJson) {

    #Read the owner ID from the bearerToken
    $ownerID = $OAuthJson.access_token.Substring(0, $OAuthJson.access_token.IndexOf('.'))

    #Get shop data
    $requirements = GetEndpointRequirements "getShopByOwnerUserId" $OAuthJson.access_token
    $shopData = MakeEtsyRequest $requirements

    #Create the container data so we can cache all this shit.
    $ShopContainer = [PSCustomObject]@{
        shop_data    = $shopData
        shop_name    = $shopData.shop_name
        shop_id      = $shopData.shop_id
        ownerId      = $ownerId
        accessToken  = $OAuthJson.access_token
        refreshToken = $OAuthJson.refresh_token
        openOrders   = $null
        allListings  = $null
    }

    return $ShopContainer
}

<#
Adds a new shop to the script.
Opens the browser and starts OAuth flow
#>
function AddShop() {
    $connectURL = GetConnectURL
    Write-host "Will navigate to: $connectURL"

    $defaultBrowser = New-Object System.Management.Automation.Host.ChoiceDescription '&Default', 'Default Browser'
    $edge = New-Object System.Management.Automation.Host.ChoiceDescription '&Edge', 'Edge'
    $chrome = New-Object System.Management.Automation.Host.ChoiceDescription '&Chrome', 'Chrome'
    $firefox = New-Object System.Management.Automation.Host.ChoiceDescription '&Firefox', 'Firefox'

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($defaultBrowser, $chrome, $edge, $firefox)
    $title = 'Select Browser'
    $message = 'What browser do you want me to use to open the OAuth URL?'
    $choice = $host.ui.PromptForChoice($title, $message, $options, 0)
    switch ($choice) {
        0 { Start-Process $connectURL }
        1 { [system.Diagnostics.Process]::Start("chrome", $connectURL) | Out-Null }
        2 { [system.Diagnostics.Process]::Start("msedge", $connectURL) | Out-Null }
        3 { [system.Diagnostics.Process]::Start("firefox", $connectURL) | Out-Null }
    }

    $OAuthKey = Read-Host -Prompt "Paste the auth key from the browser"

    $OAuthResult = GetOAuthToken $OAuthKey

    $shopInfo = CreateShop $OAuthResult
    UpdateShopFromEtsy $shopInfo
    $global:allShops.add($shopInfo)
    SaveShopsToFile
}

<#
Asks Etsy for up to data shop data, then saves to file.
#>
function RefreshAllShops() {
    foreach ($shop in $global:allShops) {
        UpdateShopFromEtsy $shop
    }

    SaveShopsToFile
}