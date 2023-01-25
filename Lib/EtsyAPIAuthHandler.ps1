Write-Host "Loading AuthHandler..." -ForegroundColor Magenta
function LoadAPIKey() {
    $destination = "$global:saveLocation\EtsyAPIKey.xml"
    if (Test-Path -Path $destination) {
        $global:apiKey = Import-Clixml $destination
        if (!$global:apiKey.Length -eq 25) {
            Write-Host "API Key has incorrect legnth!" -ForegroundColor Red
            return $false
        }
        
        if (!(TestAPIKey $global:apiKey)) {
            Write-Host "Saved API Key did not work to Ping Etsy API..." -ForegroundColor Red
            return $false
        }
        return $true
    }
    return $false
}

function SetAPIKey() {
    while ($true) {
        $global:apiKey = read-host -Prompt "Enter API Key"
        $result = TestAPIKey $global:apiKey

        if ($result.StatusCode -eq 200) {
            break
        }
        write-host "API did not work, please try again" -ForegroundColor Red
        write-host $result
    }

    $destination = "$global:saveLocation\EtsyAPIKey.xml"
    write-host "Writing API key to file: $destination"
    $global:apiKey | Export-Clixml $destination
}
$global:asd = $null
function TestAPIKey($key) {
    write-host "Testing connecting to Etsy API..."
    $header = NewDictionary
    $header.add("x-api-key", $key)

    $url = "https://api.etsy.com/v3/application/openapi-ping"

    $result = Invoke-WebRequest -Uri $url -Headers $header -Method 'GET' -MaximumRedirection 5 -ErrorAction SilentlyContinue
    if ($result.StatusCode -eq 200) {
        write-host "Connected to Etsy OpenAPI!" -ForegroundColor DarkGreen
    }

    return $result
}

function Base64URLEncode($text) {
    $base64 = [System.Convert]::ToBase64String($text)
    return $base64.replace("+", "-").replace("/", "_").replace("=", "")
}

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

function GetOAuthToken($authKey) {
    $tokenUrl = "https://api.etsy.com/v3/public/oauth/token"
    $headers = NewDictionary
    $headers.Add('Content-Type', 'application/json')

    $body = [PSCustomObject]@{
        grant_type    = 'authorization_code'
        client_id     = $global:apiKey
        redirect_uri  = $global:redirectURL
        code          = $authKey
        code_verifier = $global:codeVerifier
    }

    $body = ConvertTo-Json $body

    $result = Invoke-RestMethod -Uri $tokenUrl -Headers $headers -Body $body -Method 'POST' -MaximumRedirection 5
    return $result
}

function RefreshOAuth($shop) {
    write-host "Attempting token refresh for $($shop.shop_name)..." -ForegroundColor Yellow
    $headers = NewDictionary
    $headers.add("Content-Type", "application/x-www-form-urlencoded")

    $requestBody = NewDictionary
    $requestBody.add("grant_type", "refresh_token")
    $requestBody.add("client_id", $global:apiKey)
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