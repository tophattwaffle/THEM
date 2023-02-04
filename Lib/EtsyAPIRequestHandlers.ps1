Write-Host "Loading EtsyAPIRequestHandlers..." -ForegroundColor Magenta

$global:property_id = @{
    "Primary color"  = 200
    "Seconday color" = 52047899002
    "CUSTOM1"        = 513
    "CUSTOM2"        = 514
    "Size"           = 100

}

$global:endpoints = @{}
$global:baseUrl = "https://openapi.etsy.com/v3/application/"
$reqHistory = [System.Collections.Generic.List[int]]::new()

function SetupEndpoints() {
    $global:endpoints.Add("getListingsByShop", (CreateEndpointRequirement "shops/{shop_id}/listings?limit=100&includes=inventory" $true $true 'GET' $null))
    $global:endpoints.Add("getListingsByShop_draftOnly", (CreateEndpointRequirement "shops/{shop_id}/listings?limit=100&includes=inventory&state=draft" $true $true 'GET' $null))
    $global:endpoints.Add("getShopReceipts", (CreateEndpointRequirement "shops/{shop_id}/receipts?limit=100&was_paid=true&was_shipped=false" $true $true 'GET' $null))
    $global:endpoints.Add("updateListingInventory", (CreateEndpointRequirement "listings/{listing_id}/inventory" $true $true 'PUT' "application/json"))
    $global:endpoints.Add("getShopByOwnerUserId", (CreateEndpointRequirement "users/{user_id}/shops" $true $true 'GET' $null))
    $global:endpoints.Add("getListingImages", (CreateEndpointRequirement "listings/{listing_id}/images" $true $false 'GET' $null))
    $global:endpoints.Add("uploadListingImage", (CreateEndpointRequirement "shops/{shop_id}/listings/{listing_id}/images" $true $true 'POST' "multipart/form-data"))
    $global:endpoints.Add("deleteListingImage", (CreateEndpointRequirement "shops/{shop_id}/listings/{listing_id}/images/{listing_image_id}" $true $true 'DELETE' $null))
}

<#
Returns a dictionary containing all the needed headers to make an OAuth request.
#>
function MakeEtsyRequest($requirements, $payload = $null)
{
    $currentTime = [int](Get-Date -UFormat %s -Millisecond 0)

    $PastRequests = $reqHistory | Where-Object {$_ -eq $currentTime}
    #If we have too many past requests, delay for a second and then reset the list.
    if($PastRequests.count -gt 2)
    {
        Write-Host "Rate limiting!" -ForegroundColor Black
        $reqHistory = [System.Collections.Generic.List[int]]::new()
        Start-Sleep -Seconds 1
    }
    $reqTime = [int](Get-Date -UFormat %s -Millisecond 0)
    $reqHistory.Add($reqTime)

    if ($null -eq $payload) {
        return Invoke-RestMethod -Uri $requirements.url -Headers $requirements.headers -Method $requirements.requestType -MaximumRedirection 5
    }
    else {
        return Invoke-RestMethod -Uri $requirements.url -Headers $requirements.headers -Method $requirements.requestType -MaximumRedirection 5 -Body $payload
    }
}


<#
Takes an endpoint name and returns all the requirements for it.
Replace can take a string array and then replace the variables in the URL in order.
#>
function GetEndpointRequirements($endpoint, $authToken, $replace = $null) {
    $requirements = $global:endpoints.Get_Item($endpoint)

    $dict = NewDictionary

    if ($requirements.requiresApi) {
        $dict.add("x-api-key", $global:settings.apiKey)
    }

    if ($requirements.requiresOAuth) {
        $dict.add("Authorization", "Bearer $authToken")
    }

    if ($null -ne $requirements.contentType) {
        $dict.add("Content-Type", $requirements.contentType)
    }

    $endpoint = [PSCustomObject]@{
        headers     = $dict
        url         = "$($global:baseUrl)$($requirements.url)"
        requestType = $requirements.requestType
    }

    $match = [Regex]::Matches($endpoint.url, '\{(.*?)\}')

    if ($match.Count -eq 1) {
        $endpoint.url = $endpoint.url.Replace($match[0].value, $replace)
    }
    else {
        for ($i = 0; $i -lt $match.Count; $i++) {
            $endpoint.url = $endpoint.url.Replace($match[$i].value, $replace[$i])
        }
    }

    return $endpoint
}

function CreateEndpointRequirement($url, $requiresApi, $requiresOAuth, $requestType, $contentType) {
    $endpoint = [PSCustomObject]@{
        url           = $url
        requiresApi   = $requiresApi
        requiresOAuth = $requiresOAuth
        contentType   = $contentType
        requestType   = $requestType
    }

    return $endpoint
}