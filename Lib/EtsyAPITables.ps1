Write-Host "Loading EtsyAPITables..." -ForegroundColor Magenta

$global:property_id = @{
    "Primary color"  = 200
    "Seconday color" = 52047899002
    "CUSTOM1"        = 513
    "CUSTOM2"        = 514
    "Size"           = 100

}

$global:endpoints = @{}
$global:baseUrl = "https://openapi.etsy.com/v3/application/"

function SetupEndpoints() {
    $global:endpoints.Add("getListingsByShop", (CreateEndpointRequirement "shops/{shop_id}/listings?limit=100&includes=inventory" $true $true 'GET' $null))
    $global:endpoints.Add("getListingsByShop_draftOnly", (CreateEndpointRequirement "shops/{shop_id}/listings?limit=100&includes=inventory&state=draft" $true $true 'GET' $null))
    $global:endpoints.Add("getShopReceipts", (CreateEndpointRequirement "shops/{shop_id}/receipts?limit=100&was_paid=true&was_shipped=false" $true $true 'GET' $null))
    $global:endpoints.Add("updateListingInventory", (CreateEndpointRequirement "listings/{listing_id}/inventory" $true $true 'PUT' "application/json"))
}

<#
Takes an endpoint name and returns all the requirements for it.
Replace can take a string array and then replace the variables in the URL in order.
#>
function GetEndpointRequirements($endpoint, $authToken, $replace = $null) {
    $requirements = $global:endpoints.Get_Item($endpoint)

    $dict = NewDictionary

    if ($requirements.requiresApi) {
        $dict.add("x-api-key", $global:apiKey)
    }

    if ($requirements.requiresOAuth) {
        $dict.add("Authorization", "Bearer $authToken")
    }

    if ($requirements.contentType -ne $null) {
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
            $endpoint.url.Replace($match[$i].value, $replace[$i])
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