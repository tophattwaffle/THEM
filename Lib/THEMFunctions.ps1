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
    $UpdateListingImages = New-Object System.Management.Automation.Host.ChoiceDescription '&Update Listing Images', 'Update all listings Images based on the previously exported files.'
    $AddWebhookURL = New-Object System.Management.Automation.Host.ChoiceDescription '&Set HA Webhook URL', 'Set the webhook URL to be used with Home Assistant'

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($RefreshAllShops, $AddShop, $ExportShopInventory, $UpdateAllShopInventory, $UpdateListingImages, $AddWebhookURL)
    $title = 'What would you like to do?'
    $message = 'Please make a selection for what you would like to do...'
    $choice = $host.ui.PromptForChoice($title, $message, $options, 0)
    switch ($choice) {
        0 { RefreshAllShops }
        1 { AddShop }
        2 { ExportAllShopInventory }
        3 { UpdateAllShopInventory }
        4 { UpdateListingImages }
        5 { SetWebhookURL }
    }
}

function UpdateListingImages() {
    foreach ($shop in $global:allShops) {
        $dest = "$($global:saveLocation)\$($shop.shop_id)_shopImages.csv"

        if (!(Test-Path -Path $dest)) {
            Write-host "Cannot find $dest"
            continue
        }

        $csv = Import-Csv $dest

        foreach ($listing in $csv) {
            $images = $listing.imageTitles.split($global:settings.splitChar)
            if (0 -eq $images[0].length -or $null -eq $images) {
                Write-host "No images for $($listing.listing_id)"
                continue
            }

            $existingImages = GetAllListingImages $listing.listing_id
            
            #How many show information images do we have currently?
            $shopInfoImages = $existingImages | Where-Object {$_.alt_text -eq $($global:settings.shopImageAltText)}

            #We have more images to upload than we currently have. Let's just scrub the current images uploaded.
            if(($shopInfoImages.Count -gt 0 -or $null -ne $shopInfoImages) -and $shopInfoImages.Count -ne $images.Count)
            {
                foreach($img in $shopInfoImages)
                {
                    $rank = $img.rank
                    DeleteListingImage $shop.accessToken $shop.shop_id $($img.listing_id) $($img.listing_image_id)
                }
                
                #Refresh this data after the deletion
                $existingImages = GetAllListingImages $listing.listing_id
                $shopInfoImages = $existingImages | Where-Object {$_.alt_text -eq $($global:settings.shopImageAltText)}
            }

            #Have 10 images, just write them in from 10 backwards.
            if ($existingImages.count -eq 10) {

                #since we write in backwards, reverse the array. This does not return, but modifies the provded array
                [array]::Reverse($images)

                for ($i = 0; $i -lt $images.Count; $i++) {
                    $imagePath = "$($global:saveLocation)\images\$($images[$i])"
                    $rank = (10 - $i)
                    
                    $oldImage = $existingImages[$rank - 1]

                    if ($null -ne $oldImage) {
                        DeleteListingImage $shop.accessToken $shop.shop_id $($oldImage.listing_id) $($oldImage.listing_image_id)
                    }
                    
                    write-host "Uploading $imagePath to $($listing.title) with rank $rank"
                    $result = UploadListingImage $shop.accessToken $shop.shop_id $listing.listing_id $imagePath $rank $global:settings.shopImageAltText
                }
            }
            #We already have the same number of images as we are going to upload, just punch for punch replace em.
            elseif($shopInfoImages.Count -eq $images.Count)
            {
                for ($i = 0; $i -lt $images.Count; $i++) {
                    $imagePath = "$($global:saveLocation)\images\$($images[$i])"

                    $rank = $shopInfoImages[$i].rank
                    DeleteListingImage $shop.accessToken $shop.shop_id $($shopInfoImages[$i].listing_id) $($shopInfoImages[$i].listing_image_id)
                    write-host "Uploading $imagePath to $($listing.title) with rank $rank"
                    $result = UploadListingImage $shop.accessToken $shop.shop_id $listing.listing_id $imagePath $rank $global:settings.shopImageAltText
                }
            }   
            #No images currently exist. Upload them.
            elseif($shopInfoImages.Count -eq 0){
                $rank = $existingImages.Count

                $projectedImages = $existingImages.Count + $images.Count
                #Don't have enough room for all images, make some.
                if($projectedImages -gt 10)
                {
                    $deleteFrom = $existingImages.Count - ($projectedImages - 10)
                    for($i = $deleteFrom; $i -lt $existingImages.Count; $i++)
                    {
                        DeleteListingImage $shop.accessToken $shop.shop_id $($existingImages[$i].listing_id) $($existingImages[$i].listing_image_id)
                    }
                    $rank = $deleteFrom + 1
                }
                else {
                    #Just increment rank count once
                    $rank++
                }

                #Actually upload
                
                for ($i = 0; $i -lt $images.Count; $i++) {
                    $imagePath = "$($global:saveLocation)\images\$($images[$i])"
                    $usedRank = $i + $rank
                    write-host "Uploading $imagePath to $($listing.title) with rank $usedRank"
                    $result = UploadListingImage $shop.accessToken $shop.shop_id $listing.listing_id $imagePath $usedRank $global:settings.shopImageAltText                    
                }
            }
        }
    }
    write-host "end of UpdateListingImages"
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
    $shop.openOrders = GetAllOpenOrders $shop.accessToken $shop.shop_id

    if ($null -ne $global:settings.webhookUrl) {
        $body = @{
            shop_id    = $shop.shop_id
            openOrders = $shop.openOrders.count
        }

        if ($null -eq $shop.openOrders) { $body.openOrders = 0 }
        elseif ($null -eq $shop.openOrders.count) { $body.openOrders = 1 }

        Invoke-RestMethod -Uri $global:settings.webhookUrl -Method 'POST' -Body (ConvertTo-Json $body)
    }

    #Don't get listing information if we are auto
    if ($global:runMode -ne "auto") {
        $shop.allListings = GetAllListings $shop.accessToken $shop.shop_id
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

            $result = UpdateListingInventory $shop.accessToken $product.listing_id $updateBody
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
                        quantity       = $i.quantity
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
                        quantity      = $i.quantity
                        property_name = $i.priVarName
                        value         = $value
                        price         = $price
                        scale_id      = if ($i.priScale_id) { $i.priScale_id } else { $null }
                    })
            }
            foreach ($x in $invtoryList.secList) {
                $list.Add([SingleOrNoPriceVariation]@{
                        quantity      = $i.quantity
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

    createShopImagesCSV $shop
}

<#
Provided with a shop, creates / updates the ShopImages csv file so you can assign images to a listing.
#>
function createShopImagesCSV($shop) {
    $dest = "$($global:saveLocation)\$($shop.shop_id)_shopImages.csv"
    $list = [System.Collections.Generic.List[Object]]::new()

    #Read the existing listings into the file.
    if ((Test-Path -Path $dest)) {
        $import = Import-Csv $dest

        foreach ($i in $import) {
            $list.Add($i)
        }
    }

    foreach ($listing in $shop.allListings) {
        #Skip existing listings
        $exists = $false
        foreach ($i in $list) {
            if ($i.listing_id -eq $listing.listing_id.ToString()) {
                $exists = $true
                break
            }
        }
        if ($exists) { continue }
            
        $obj = [PSCustomObject]@{
            listing_id  = $null
            title       = $null
            imageTitles = $null
        } 

        $obj.listing_id = $listing.listing_id
        if ($listing.title.Length -ge 30) { $obj.title = $listing.title.Substring(0, 30) }
        else { $obj.title = $listing.title }

        $list.Add($obj)
    }
    $list | Export-Csv -Path $dest -NoTypeInformation
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

function GetAllShopImagesFromFolder($shop_id) {
    return Get-ChildItem -Path "$global:saveLocation\Images" | Where-Object { $_.Name.contains("$shop_id") }
}