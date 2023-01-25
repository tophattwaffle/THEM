Write-Host "Loading EtsyAPICalls..." -ForegroundColor Magenta

<#
Gets all ACTIVE listings for a shopIP
#>
function GetAllListings($shopId, $bearerToken) {


    $url = "https://openapi.etsy.com/v3/application/shops/$($shopId)/listings?limit=100&includes=inventory"

    if($global:DraftsOnly)
    {
        $url += "&state=draft"
    }

    $result = MakeOAuthRequest $bearerToken $url $null 'GET'
    $result = $result.results

    return $result
}

<#
Gets all open orders for a shop ID
#>
function GetAllOpenOrders($shopId, $bearerToken) {
    $url = "https://openapi.etsy.com/v3/application/shops/$($shopId)/receipts?was_paid=true&was_shipped=false"
    $result = MakeOAuthRequest $bearerToken $url $null 'GET'
    return $result.results
}

<#
Takes a listing ID and JSON formatted body of inventory to update for the provided listing ID
#>
function UpdateListingInventory ($listingId, $body, $accessToken) {
    $url = "https://openapi.etsy.com/v3/application/listings/$listingId/inventory"
    $result = MakeOAuthRequest $global:allShops[0].accessToken $url $body 'PUT'
    return $result
}