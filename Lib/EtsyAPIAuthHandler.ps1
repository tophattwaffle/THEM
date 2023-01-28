Write-Host "Loading AuthHandler..." -ForegroundColor Magenta

<#
Loads the API key from the saved XML file.
#>
function LoadAPIKey() {
    $loadResult = LoadSettings
    if ($loadResult) {
        if (!$global:settings.apiKey.Length -eq 25) {
            Write-Host "API Key has incorrect legnth!" -ForegroundColor Red
            return $false
        }
            
        if (!(TestAPIKey $global:settings.apiKey)) {
            Write-Host "Saved API Key did not work to Ping Etsy API..." -ForegroundColor Red
            return $false
        }
        return $true
    }
    return $false
}

<#
Gets the API key from the user. If valid saves it and sets it.
#>
function SetAPIKey() {
    while ($true) {
        $global:settings.apiKey = read-host -Prompt "Enter API Key"
        $result = TestAPIKey $global:settings.apiKey

        if ($result.StatusCode -eq 200) {
            break
        }
        write-host "API did not work, please try again" -ForegroundColor Red
        write-host $result
    }
    SaveSettings
}

<#
Tests that the provided API key works for connecting to Etsy
#>
function TestAPIKey($key) {
    write-host "Testing connecting to Etsy API..."
    $header = NewDictionary
    $header.add("x-api-key", $key)

    $url = "$($global:baseUrl)openapi-ping"

    $result = Invoke-WebRequest -Uri $url -Headers $header -Method 'GET' -MaximumRedirection 5 -ErrorAction SilentlyContinue
    if ($result.StatusCode -eq 200) {
        write-host "Connected to Etsy OpenAPI!" -ForegroundColor DarkGreen
    }

    return $result
}

<#
Takes a string and converts it to base64.
Needed to OAuth process.
#>
function Base64URLEncode($text) {
    $base64 = [System.Convert]::ToBase64String($text)
    return $base64.replace("+", "-").replace("/", "_").replace("=", "")
}

<#
Creates a new SHA256 hash.
Needed to OAuth process.
#>
function CreateHash {
    Param (
        [Parameter(Mandatory = $true)]
        [string]
        $ClearString
    )

    $hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
    $hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($ClearString))
    return $hash
}

<#
Generates a unique code to be used in a challange.
Needed to OAuth process.
#>
function CodeGenerator() {
    #gets 32 random bytes
    $randomBytes = 1..32 | % { [byte](Get-Random -Minimum ([byte]::MinValue) -Maximum ([byte]::MaxValue)) }
    $global:codeVerifier = Base64URLEncode $randomBytes

    $sha = CreateHash $global:codeVerifier
    $global:codeChallenge = Base64URLEncode $sha

    write-host "Challenge: $global:codeChallenge"
    write-host "Verifier: $global:codeVerifier"

    return $global:codeChallenge
}

<#
Creates the Connection URL for initial connection to Etsy.
Needed to OAuth process.
#>
function GetConnectURL() {
    $formattedScopes = ""

    foreach ($scope in $global:scopes) {
        $formattedScopes += "$($scope)%20" 
    }

    $formattedScopes = $formattedScopes.TrimEnd("%20")
    $global:codeChallenge = CodeGenerator
    $global:state = [Convert]::ToString((Get-Random), 16).substring(0, 5)
    write-host "State: $global:state"

    $BaseURL = "https://www.etsy.com/oauth/connect?response_type=code$(
    )&redirect_uri=$redirectURL$(
    )&scope=$formattedScopes$(
    )&client_id=$apiKey$(
    )&state=$global:state$(
    )&code_challenge=$global:codeChallenge$(
    )&code_challenge_method=S256"

    return $BaseURL
}

<#
Requests a new OAuth token from Etsy.
#>
function GetOAuthToken($authKey) {
    $tokenUrl = "https://api.etsy.com/v3/public/oauth/token"
    $headers = NewDictionary
    $headers.Add('Content-Type', 'application/json')

    $body = [PSCustomObject]@{
        grant_type    = 'authorization_code'
        client_id     = $global:settings.apiKey
        redirect_uri  = $global:redirectURL
        code          = $authKey
        code_verifier = $global:codeVerifier
    }

    $body = ConvertTo-Json $body

    $result = Invoke-RestMethod -Uri $tokenUrl -Headers $headers -Body $body -Method 'POST' -MaximumRedirection 5
    return $result
}

<#
Refreshes the OAuth token for the provided shop.
#>
function RefreshOAuth($shop) {
    write-host "Attempting token refresh for $($shop.shop_name)..." -ForegroundColor Yellow
    $headers = NewDictionary
    $headers.add("Content-Type", "application/x-www-form-urlencoded")

    $requestBody = NewDictionary
    $requestBody.add("grant_type", "refresh_token")
    $requestBody.add("client_id", $global:settings.apiKey)
    $requestBody.add("refresh_token", $shop.refreshToken)

    $refreshUrl = "https://api.etsy.com/v3/public/oauth/token"

    $result = Invoke-WebRequest -Uri $refreshUrl -Headers $headers -Body $requestBody -Method 'POST' -MaximumRedirection 5
    $json = ConvertFrom-Json $result.content

    $shop.accessToken = $json.access_token
    $shop.refreshToken = $json.refresh_token

    if ($result.StatusCode -eq 200) {
        write-host "`tRefresh success!" -ForegroundColor Green
        return $true
    }

    write-host "`tRefresh failure!" -ForegroundColor Red
    return $false
}

<#
Starts the script by loading all needed data and verifying connection to Etsy.
#>
function Init {

    #Make the folder for saving data, if needed.
    if (!(Test-Path $global:saveLocation)) {
        New-Item -ItemType Directory -Force -Path $global:saveLocation
    }

    SetupEndpoints

    $apiLoadResult = LoadAPIKey

    #Saved API key invalid, or didn't work. Get new API key from user.
    if (!$apiLoadResult) {
        SetAPIKey
    }

    #Load saved shops from file
    LoadShopsFromFile

    foreach ($shop in $global:allShops) {
        RefreshOAuth $shop | Out-Null
        if (!$global:dontRefreshOnLoad) {
            UpdateShopFromEtsy $shop
            SaveShopsToFile
        }
    }
    #Save shops after the initial refresh
}