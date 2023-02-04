Write-Host "Loading EtsyAPICalls..." -ForegroundColor Magenta

<#
Gets all ACTIVE listings for a shopID
#>
function GetAllListings($bearerToken, $shopId) {

    if ($global:DraftsOnly) {
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
function GetAllOpenOrders($bearerToken, $shopId) {
    $requestRequirements = GetEndpointRequirements "getShopReceipts" $bearerToken $shopId
    $result = MakeEtsyRequest $requestRequirements
    return $result.results
}

<#
Gets all images from a listing ID.
#>
function GetAllListingImages($listingId) {
    $requestRequirements = GetEndpointRequirements "getListingImages" $null $listingId
    $result = MakeEtsyRequest $requestRequirements
    return $result.results
}

<#
Deletes a listing image
#>
function DeleteListingImage ($accessToken, $shopID, $listingID, $listingImageID)
{
    $requestRequirements = GetEndpointRequirements "deleteListingImage" $accessToken ($shopID, $listingID, $listingImageID)
    $result = MakeEtsyRequest $requestRequirements
    return $result.results
}

<#
Provided with a shop_id, listing_id, a path to a local image, the rank (spot to put it on the listing)
and altText, will upload an image to a list.
#>
function UploadListingImage($accessToken, $shopID, $listingID, $image, $rank, $altText) {
    $requestRequirements = GetEndpointRequirements "uploadListingImage" $accessToken ($shopID, $listingID)

    #This is the only way to send multipart form data in PowerShell 5.x,
    #Which is to say you can't and must use the c# types instead.
    Try {
        $client = New-Object System.Net.Http.HttpClient
        $content = New-Object System.Net.Http.MultipartFormDataContent
        $fileStream = [System.IO.File]::OpenRead($image)
        $fileName = [System.IO.Path]::GetFileName($image)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $content.Add([System.Net.Http.StringContent]::new($rank + ""), "rank")
        $content.Add([System.Net.Http.StringContent]::new(($altText + "")), "alt_text")
        $content.Add($fileContent, "image", $fileName)
        $client.DefaultRequestHeaders.Add('x-api-key', $requestRequirements.headers.'x-api-key')
        $client.DefaultRequestHeaders.Add('Authorization', $requestRequirements.headers.Authorization)

        $result = $client.PostAsync($requestRequirements.url, $content).Result
        $result.EnsureSuccessStatusCode()
    }
    Catch {
        Write-Error $_
    }
    Finally {
        if ($null -ne $client) { $client.Dispose() }
        if ($null -ne $content) { $content.Dispose() }
        if ($null -ne $fileStream) { $fileStream.Dispose() }
        if ($null -ne $fileContent) { $fileContent.Dispose() }
    }
    return $result
}

<#
Takes a listing ID and JSON formatted body of inventory to update for the provided listing ID
#>
function UpdateListingInventory ($accessToken, $listingId, $body) {
    $requestRequirements = GetEndpointRequirements "updateListingInventory" $accessToken $listingId
    $result = MakeEtsyRequest $requestRequirements $body
    return $result
}