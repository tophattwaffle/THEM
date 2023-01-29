Write-Host "Loading THEMFunctions..." -ForegroundColor Magenta

function SaveSettings() {
    $destination = "$global:saveLocation\EtsyAPIsettings.xml"
    write-host "Saving settings to: $destination"
    $global:settings | Export-Clixml $destination
}

function LoadSettings() {
    $destination = "$global:saveLocation\EtsyAPIsettings.xml"
    if (Test-Path -Path $destination) {
        $global:settings = Import-Clixml $destination
        return $true
    }
    return $false
}

<#
Main menu function.
#>
function MainMenu() {
    $RefreshAllShops = New-Object System.Management.Automation.Host.ChoiceDescription '&Refresh Shop Data', 'Asks for new shop data from Etsy'
    $AddShop = New-Object System.Management.Automation.Host.ChoiceDescription '&Add New Shop', 'Adds a new shop to be managed by this application'
    $ExportShopInventory = New-Object System.Management.Automation.Host.ChoiceDescription '&Export Listing Inventory', 'Exports all listings inventories to CSV. Useful for managing variations.'
    $UpdateAllShopInventory = New-Object System.Management.Automation.Host.ChoiceDescription '&Update Listing Inventory', 'Update all listings inventories based on the previously exported files.'
    $AddWebhookURL = New-Object System.Management.Automation.Host.ChoiceDescription '&Set HA Webhook URL', 'Set the webhook URL to be used with Home Assistant'

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($RefreshAllShops, $AddShop, $ExportShopInventory, $UpdateAllShopInventory, $AddWebhookURL)
    $title = 'What would you like to do?'
    $message = 'Please make a selection for what you would like to do...'
    $choice = $host.ui.PromptForChoice($title, $message, $options, 0)
    switch ($choice) {
        0 { RefreshAllShops }
        1 { AddShop }
        2 { ExportAllShopInventory }
        3 { UpdateAllShopInventory }
        4 { SetWebhookURL }
    }
}

function SetWebhookURL() {
    $global:settings.webhookUrl = Read-Host -Prompt "Paste webhook URL"
    SaveSettings
}

<#
Updates all loaded shops from Etsy.
#>
function UpdateShopFromEtsy($shop) {
    Write-host "Getting shop information for $($shop.shop_name)..." -ForegroundColor Cyan
    $shop.openOrders = GetAllOpenOrders $shop.shop_id $shop.accessToken

    if ($null -ne $global:settings.webhookUrl) {
        $body = @{
            shop_id    = $shop.shop_id
            openOrders = $shop.openOrders.count
        }

        Invoke-RestMethod -Uri $global:settings.webhookUrl -Method 'POST' -Body (ConvertTo-Json $body)
    }

    #Don't get listing information if we are auto
    if ($global:runMode -ne "auto") {
        $shop.allListings = GetAllListings $shop.shop_id $shop.accessToken
    }

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
    $requirements = GetEndpointRequirements "getShopByOwnerUserId" $OAuthJson.access_token $ownerID
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
Exports all shops inventories to a CSV file.
#>
function ExportAllShopInventory() {
    foreach ($shop in $global:allShops) {
        Write-host "Exporting $($shop.shop_name) to CSV!"
        ExportShopInventory $shop
    }
}

<#
Updates all shops inventories from the saved CSV files
#>
function UpdateAllShopInventory() {
    foreach ($shop in $global:allShops) {
        $inventories = ImportShopInventories $shop

        foreach ($inv in $inventories.Keys) {
            $i = $inventories[$inv]
            $product = $shop.allListings | Where-Object { $_.listing_id -eq $inv }#GET PROD 

            $updateBody = CreateUpdateListingInventoryFromList $product $i

            $result = UpdateListingInventory $product.listing_id $updateBody $shop.accessToken
            if ($null -ne $result) {
                write-host "Updated $($product.title) inventory!" -ForegroundColor Green
            }
            else {
                write-host "Issue with $($product.title) inventory update!" -ForegroundColor Red
            }
        }
    }
}

<#
Provided with a shop object, will read the CSV files and import them into a format that can be
sent to the update endpoint.
#>
function ImportShopInventories($shop) {
    $path = "$($global:saveLocation)\$($shop.shop_id)_inventory.csv"
    if (!(Test-Path -Path $path)) {
        Write-host "Cannot find $path" -ForegroundColor Red
        Write-host "Did you export it yet?" -ForegroundColor Red
        return
    }
    #Store each list of parsed object mapped to the listing_id
    $dict = [System.Collections.Generic.Dictionary[[int64], [object]]]::new()
    $importedInventory = Import-Csv $path

    foreach ($i in $importedInventory) {
        #Skip listings that we don't want to do anything with.
        if ("" -eq $i.actions) { 
            write-host "Skipping $($i.title) becuase actions are blank!" -ForegroundColor Magenta
            continue
        }

        $list = [System.Collections.Generic.List[Object]]::new()
        $invtoryList = ReadCSVFormatVariationsIntoList $i

        #Determine if this object has prices dependant on both variations
        $isDoublePriceVariation = $false
        foreach ($j in $invtoryList.priList) {
            $split = $j.split($global:settings.splitChar)
            if ($split.count -eq 3) {
                $isDoublePriceVariation = $true
                break
            }
        }

        if ($isDoublePriceVariation) {
            foreach ($x in $invtoryList.priList) {
                $splits = $x.split($global:settings.splitChar)
                $list.Add([DoublePriceVariation]@{
                        property_name  = $i.priVarName
                        value          = $splits[0]
                        property_name2 = $i.secVarName
                        value2         = $splits[2]
                        price          = $splits[1] -as [double]
                        priScale_id    = if ($i.priScale_id) { $i.priScale_id } else { $null }
                        secScale_id    = if ($i.secScale_id) { $i.secScale_id } else { $null }
                    })
            }
        }
        else {
            foreach ($x in $invtoryList.priList) {
                $price = $null
                $value = $x
                $xSplits = $x.split($global:settings.splitChar)
                if ($xSplits.count -eq 2) {
                    $value = $xSplits[0]
                    $price = $xSplits[1] -as [double]
                }

                $list.Add([SingleOrNoPriceVariation]@{
                        property_name = $i.priVarName
                        value         = $value
                        price         = $price
                        scale_id      = if ($i.priScale_id) { $i.priScale_id } else { $null }
                    })
            }
            foreach ($x in $invtoryList.secList) {
                $list.Add([SingleOrNoPriceVariation]@{
                        property_name = $i.secVarName
                        value         = $x
                        price         = $null
                        scale_id      = if ($i.secScale_id) { $i.secScale_id } else { $null }
                    })
            }
        }

        $dict.Add($i.listing_id, $list)
        
    }
    return $dict
}

<#
Provided with a CSV imported inventory, returns a hashtable with 2 lists
priList and secList with the primary variations and secondary variations as string lists.
#>
function ReadCSVFormatVariationsIntoList($csvInventory) {

    $list = @{
        priList = [System.Collections.Generic.List[String]]::new()
        secList = [System.Collections.Generic.List[String]]::new()
    }

    for ($i = 0; $i -lt $global:settings.csvVariationLimit; $i++) {
        $obj = GetValueByString $csvInventory "priVarValue$($i)"
        if ($obj) { $list.priList.add($obj) }
    }

    for ($i = 0; $i -lt $global:settings.csvVariationLimit; $i++) {
        $obj = GetValueByString $csvInventory "secVarValue$($i)"
        if ($obj) { $list.secList.add($obj) }
    }

    return $list
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

<#
Provided with a shop object, exports all listing inventories to a CSV file.
#>
function ExportShopInventory($shop) {
    $list = [System.Collections.Generic.List[Object]]::new()
    foreach ($listing in $shop.allListings) {
        $itemVariations = GetAllVariationsFromListing $listing
        $variationTitles = GetVariationTitlesFromList $itemVariations
            
        $struct = GetNewInventoryExportStructure

        $struct.listing_id = $listing.listing_id
        $struct.quantity = $listing.quantity
        if ($listing.title.Length -ge 30) { $struct.title = $listing.title.Substring(0, 30) }
        else { $struct.title = $listing.title }

        #No variations. Bail
        if ($null -eq $itemVariations) {
            $list.Add($struct)
            continue
        }

        $priceProps = $listing.inventory.price_on_property

        switch ($itemVariations[0].GetType().Name) {            
            "SingleOrNoPriceVariation" {
                $primaryVariations = ($itemVariations | Where-Object { $_.property_name -eq $variationTitles[0] })
                $secondaryVariations = ($itemVariations | Where-Object { $_.property_name -eq $variationTitles[1] })

                if ($variationTitles.count -gt 0) {
                    $struct.priVarName = $variationTitles[0]
                    for ($i = 0; $i -lt $primaryVariations.count; $i++) {
                        $valueToAdd = $primaryVariations[$i].value
        
                        #Single price set variations are handled on primary variation ONLY
                        if ($null -ne $primaryVariations[$i].price -and $priceProps.count -eq 1) {
                            $valueToAdd += "$($global:settings.splitChar)$($primaryVariations[$i].price)"
                        }
        
                        SetValueByString $struct "priVarValue$($i)" $valueToAdd
                        $struct.priScale_id = $primaryVariations[$i].scale_id
                    }
                }
        
                if ($variationTitles.count -eq 2) {
                    $struct.secVarName = $variationTitles[1]
                    for ($i = 0; $i -lt $secondaryVariations.count; $i++) {
                        SetValueByString $struct "secVarValue$($i)" $secondaryVariations[$i].value
                        $struct.secScale_id = $secondaryVariations[$i].scale_id
                    }
                }
            }
    
            "DoublePriceVariation" {
                $struct.priVarName = $variationTitles[0]
                $struct.secVarName = $variationTitles[1]
                $struct.priScale_id = $itemVariations[0].priScale_id
                $struct.secScale_id = $itemVariations[0].sec
                for ($i = 0; $i -lt $itemVariations.count; $i++) {
                    $v = $itemVariations[$i]
                    SetValueByString $struct "priVarValue$($i)" "$($v.value)$($global:settings.splitChar)$($v.price)$($global:settings.splitChar)$($v.value2)"
                        
                }
            }
            
        }

        $list.Add($struct)
    }
    $dest = "$($global:saveLocation)\$($shop.shop_id)_inventory.csv"
    $list | Export-Csv -Path $dest -NoTypeInformation
    write-host "Exported to $dest"
}

function SetValueByString($object, $key, $Value) {
    $p1, $p2 = $key.Split(".")
    if ($p2) { SetValueByString -object $object.$p1 -key $p2 -Value $Value }
    else { $object.$p1 = $Value }
}

function GetValueByString($object, $key) {
    $p1, $p2 = $key.Split(".")
    if ($p2) { return GetValueByString -object $object.$p1 -key $p2 }
    else { return $object.$p1 }
}

function GetNewInventoryExportStructure {
    $obj = [PSCustomObject]@{
        actions     = $null
        listing_id  = $null
        quantity    = $null
        title       = $null
        priScale_id = $null
        secScale_id = $null
        priVarName  = $null
        secVarName  = $null
    } 

    for ($i = 0; $i -lt $global:settings.csvVariationLimit; $i++) {
        $obj | Add-Member -NotePropertyName "priVarValue$($i)" -NotePropertyValue $null
    }

    for ($i = 0; $i -lt $global:settings.csvVariationLimit; $i++) {
        $obj | Add-Member -NotePropertyName "secVarValue$($i)" -NotePropertyValue $null
    }

    return $obj
}