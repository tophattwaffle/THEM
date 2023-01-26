Write-Host "Loading EtsyAPIRequestHandlers..." -ForegroundColor Magenta

<#
Returns a dictionary containing all the needed headers to make an OAuth request.
#>
function GetOAuthRequestHeaders($authToken, $reqType) {
    $dict = NewDictionary

    $dict.add("x-api-key", $global:apiKey)
    $dict.add("Authorization", "Bearer $authToken")

    if ($reqType -like 'PUT') {
        $dict.add("Content-Type", "application/json")
    }
    else {
        $dict.add("Content-Type", "application/x-www-form-urlencoded")
    }

    return $dict
}

function MakeEtsyRequest($requirements, $payload = $null)
{
    if ($payload -eq $null) {
        return Invoke-RestMethod -Uri $requirements.url -Headers $requirements.headers -Method $requirements.requestType -MaximumRedirection 5
    }
    else {
        return Invoke-RestMethod -Uri $requirements.url -Headers $requirements.headers -Method $requirements.requestType -MaximumRedirection 5 -Body $payload
    }
}

<#
Makes an OAuth request to the provided endpoint.
#>
function MakeOAuthRequest($bearerToken, $url, $body, $requestType) {
    $reqHeaders = GetOAuthRequestHeaders $bearerToken $requestType

    if ($body -eq $null) {
        $result = Invoke-RestMethod -Uri $url -Headers $reqHeaders -Method $requestType -MaximumRedirection 5
    }
    else {
        $result = Invoke-RestMethod -Uri $url -Headers $reqHeaders -Method $requestType -MaximumRedirection 5 -Body $body
    }

    return $result
}

<#
Gets the required headers for a request that only needs an API key.
#>
function GetAPIKeyRequestHeaders() {
    $dict = NewDictionary
    $dict.add("Content-Type", "application/x-www-form-urlencoded")
    $dict.add("x-api-key", $global:apiKey)

    return $dict
}

<#
Makes an API key request.
#>
function MakeAPIKeyRequest($url, $body, $requestType) {

    $reqHeaders = GetAPIKeyRequestHeaders

    if ($body -ne $null) {
        $result = Invoke-RestMethod -Uri $url -Headers $reqHeaders -Body $body -Method $requestType -MaximumRedirection 5
    }
    else {
        $result = Invoke-RestMethod -Uri $url -Headers $reqHeaders -Method $requestType -MaximumRedirection 5
    }

    return $result
}