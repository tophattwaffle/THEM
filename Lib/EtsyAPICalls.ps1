Write-Host "Loading EtsyAPICalls..." -ForegroundColor Magenta

<#
Gets all ACTIVE listings for a shopID
#>
function GetAllListings($shopId, $bearerToken) {

    if($global:DraftsOnly)
    {
        $requestRequirements = GetEndpointRequirements "getListingsByShop_draftOnly" $bearerToken $shopId
    }
    else {
        $requestRequirements = GetEndpointRequirements "getListingsByShop" $bearerToken $shopId
    }

    $result = MakeEtsyRequest $requestRequirements

    return $result.results
}

<#
Gets all open orders for a shop ID
#>
function GetAllOpenOrders($shopId, $bearerToken) {
    $requestRequirements = GetEndpointRequirements "getShopReceipts" $bearerToken $shopId
    $result = MakeEtsyRequest $requestRequirements
    return $result.results
}

<#
Takes a listing ID and JSON formatted body of inventory to update for the provided listing ID
#>
function UpdateListingInventory ($listingId, $body, $accessToken) {
    $requestRequirements = GetEndpointRequirements "updateListingInventory" $bearerToken $shopId
    $result = MakeEtsyRequest $requestRequirements $body
    return $result.results
}