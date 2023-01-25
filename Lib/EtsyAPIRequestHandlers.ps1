Write-Host "Loading EtsyAPIRequestHandlers..." -ForegroundColor Magenta

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

function GetAPIKeyRequestHeaders() {
    $dict = NewDictionary
    $dict.add("Content-Type", "application/x-www-form-urlencoded")
    $dict.add("x-api-key", $global:apiKey)

    return $dict
}

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