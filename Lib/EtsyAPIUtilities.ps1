Write-Host "Loading EtsyAPIUtilities..." -ForegroundColor Magenta

function NewDictionary() {
    return New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
}

function NewStringList() {
    return New-Object 'System.Collections.Generic.List[string]]'
}

function SaveShopsToFile() {
    $destination = "$global:saveLocation\EtsyAPI.xml"
    write-host "Writing all shops to: $destination"
    Export-Clixml -InputObject $global:allShops -Path $destination
}

function LoadShopsFromFile() {
    $destination = "$global:saveLocation\EtsyAPI.xml"
    if (Test-Path -Path $destination) {
        write-host "Reading all shops from: $destination"
        $global:allShops = Import-Clixml $destination
        foreach ($s in $global:allShops) {
            write-host "$($s.shop_name) Loaded from saved data!"
        }
    }
    else {
        Write-Host "Saved shop data not found. Please connect to API..."
    }
}

<#
Gets all variations from a listing and parses them into a sorted list.
#>
function GetAllVariationsFromListing($listing) {
    $list = [System.Collections.Generic.List[Object]]::new()

    $pricingProperties = $listing.inventory.price_on_property

    if($pricingProperties.count -eq 0)
    {
        return $list
    }
    
    #Handle pricing on a single property!
    if ($pricingProperties.count -le 1) {
        foreach ($product in $listing.inventory.products) {
            $list.Add([SingleOrNoPriceVariation]@{
                    property_name     = $product.property_values[0].property_name
                    value             = $product.property_values[0].values[0]
                    price             = $product.offerings[0].price.amount / $product.offerings[0].price.divisor
                    scale_id          = $product.property_values[0].scale_id
                })

            #There is a 2nd variation on listing
            if ($product.property_values.count -eq 2) {
                $list.Add([SingleOrNoPriceVariation]@{
                        property_name     = $product.property_values[1].property_name
                        value             = $product.property_values[1].values[0]
                        price             = $product.offerings[0].price.amount / $product.offerings[0].price.divisor
                        scale_id          = $product.property_values[1].scale_id
                    })
            }
        }

        #If the price property does not match the property_name, null the price.
        foreach ($i in $list) {
            $thisPropId = GetProperty_id $i.property_name
            if ($thisPropId -ne $pricingProperties[0]) {
                $i.price = $null
            }
        }
    }

    #Handle pricing when on BOTH properties
    #Safe to assume there are 2 variations since there is pricing on 2 props
    elseif ($pricingProperties.count -eq 2) {
        foreach ($product in $listing.inventory.products) {
            $list.Add([DoublePriceVariation]@{
                    property_name     = $product.property_values[0].property_name
                    value             = $product.property_values[0].values[0]
                    property_name2    = $product.property_values[1].property_name
                    value2            = $product.property_values[1].values[0]
                    price             = $product.offerings[0].price.amount / $product.offerings[0].price.divisor
                    priScale_id          = $product.property_values[0].scale_id
                    secScale_id          = $product.property_values[1].scale_id
                })
        }
    }

  
    #return based on the type.
    switch ($list[0].GetType().Name) {
        #De dupe, sort output
        "SingleOrNoPriceVariation" {
            return $list | Group-Object -Property 'property_name', 'value' | ForEach-Object { $_.Group[0] } | Sort-Object -Property 'property_name'
        }

        #no sorting needed, every combination is manually defined.
        "DoublePriceVariation" {
            return $list
        }
    }

    #Failure return null?
    return $null
}

class SingleOrNoPriceVariation {
    [string]$property_name
    [string]$value
    [nullable[float]]$price
    [nullable[int]]$scale_id
}

class DoublePriceVariation {
    [string]$property_name
    [string]$value
    [string]$property_name2
    [string]$value2
    [float]$price
    [nullable[int]]$priScale_id
    [nullable[int]]$secScale_id
}

<#
Takes a product and a list and will return JSON formatted data ready for UpdateListingInventory.
Use this to generate the required data to update after all things are in the local objects.
#>
function CreateUpdateListingInventoryFromList($product, $list) {
    switch ($list[0].GetType().Name) {
        "SingleOrNoPriceVariation" {
            $result = CreateJsonSingleOrNoPriceVariation $product $list

            #Make sure price on prop is set correctly by first checking if we have unique pricing.
            $list = [System.Collections.Generic.List[float]]::new()
            foreach($p in $result.products)
            {
                #add all prices to list
                $list.add($p.offerings[0].price)
            }
            #De-dupe the list
            $list = $list | Group-Object | ForEach-Object { $_.Group[0] }
            #If the list has more than 1 item, we have unique pricing and need to set the prop.
            if($list.Count -gt 1)
            {
                $result.price_on_property = @($result.products[0].property_values[0].property_id)
            }
        }

        #I don't think order matters for this one???
        "DoublePriceVariation" {
            $result = CreateJsonDoublePriceVariation $product $list
            
            #Set the price on properties to be each prop value.
            $result.price_on_property = @($result.products[0].property_values[0].property_id, $result.products[0].property_values[1].property_id)
        }
    }

    $result = ConvertTo-Json $result -Depth 99

    return $result
}

<#
Provided with a product and a list with 2 variations with prices dependant on both variation properties.
Returns an inventory schema that can be sent with UpdateListingInventory call

Typically you'll want to use GetAllVariationsFromListing to get the varitions, then append your own to that before using this.
#>
function CreateJsonDoublePriceVariation($product, $list)
{
    $inventorySchema = GetInventorySchema $product
    foreach ($i in $list) {
        $productSchema = GetEmptyProductSchema

        $productSchema.property_values += (GetEmptyPropertyValuesSchema)
        $productSchema.property_values += (GetEmptyPropertyValuesSchema)

        $productSchema.sku = if ($null -eq $product.sku) { "" } else { $product.sku }
        $productSchema.property_values[0].property_id = (GetProperty_id $i.property_name)
        $productSchema.property_values[0].scale_id = $i.priScale_id
        $productSchema.property_values[0].property_name = $i.property_name
        $productSchema.property_values[0].values[0] = $i.value

        $productSchema.property_values[1].property_id = (GetProperty_id $i.property_name2)
        $productSchema.property_values[1].scale_id = $i.secScale_id
        $productSchema.property_values[1].property_name = $i.property_name2
        $productSchema.property_values[1].values[0] = $i.value2

        $productSchema.offerings[0].price = $i.price
        $productSchema.offerings[0].quantity = $product.quantity
        $productSchema.offerings[0].is_enabled = $true

        if($productSchema.property_values[0].property_id -eq $productSchema.property_values[1].property_id)
        {
            $productSchema.property_values[1].property_id = (GetProperty_id "CUSTOM2")
        }

        $inventorySchema.products += $productSchema
    }
    return $inventorySchema
}

<#
Provided with a list of variations, returns a list with just the names of the variation types.
#>
function GetVariationTitlesFromList($list) {
    if($null -eq $list)
    {
        return
    }
    #Determine the number of variations in the list.
    $variationNames = [System.Collections.Generic.List[String]]::new()
    switch ($list[0].GetType().Name) {
        "SingleOrNoPriceVariation" {
            foreach ($i in $list) {
                $variationNames.Add($i.property_name)
            }
        }

        #I don't think order matters for this one???
        "DoublePriceVariation" {
            $variationNames.Add($list[0].property_name)
            $variationNames.Add($list[0].property_name2)
        }
    }

    [array]$variationNames = $variationNames | Select-Object -Unique

    return , $variationNames 
}

<#
Provided with a product and a list with 1 or 2 variations and can support SINGLE variation pricing
Returns an inventory schema that can be sent with UpdateListingInventory call
#>
function CreateJsonSingleOrNoPriceVariation($product, $list) {
    $variationsTitles = GetVariationTitlesFromList $list
    #If we have 2 different variations, split the lists.
    if ($variationsTitles.count -eq 2) {
        $var2list = $list | Where-Object property_name -like $variationsTitles[1]
        $var1list = $list | Where-Object property_name -like $variationsTitles[0]

        $list = [System.Collections.Generic.List[Object]]::new()
        #For item in the 2nd list, copy the first list onto itself.
        foreach ($i in $var2list) {
            $list.AddRange($var1list)
        }
    }

    #Sort the list, this is needed for when we handle the 2nd variation later
    $list = $list | Sort-Object -Property { $_.value }

    $inventorySchema = GetInventorySchema $product
    foreach ($i in $list) {
        $productSchema = GetEmptyProductSchema

        $productSchema.property_values += (GetEmptyPropertyValuesSchema)

        $productSchema.sku = if ($null -eq $product.sku) { "" } else { $product.sku }
        $productSchema.property_values[0].property_id = (GetProperty_id $i.property_name)
        $productSchema.property_values[0].scale_id = $i.scale_id
        $productSchema.property_values[0].property_name = $i.property_name
        $productSchema.property_values[0].values[0] = $i.value

        if ($null -eq $i.price) {
            $productSchema.offerings[0].price = $product.price.amount / $product.price.divisor
        }
        else {
            $productSchema.offerings[0].price = $i.price
        }

        $productSchema.offerings[0].quantity = $product.quantity
        $productSchema.offerings[0].is_enabled = $true

        $inventorySchema.products += $productSchema
    }

    #single variation, return here.
    if ($variationsTitles.count -ne 2) { return $inventorySchema }
    
    for ($i = 0; $i -lt $list.count; $i += $var2list.count) {
        for ($j = 0; $j -lt $var2list.count; $j++) {
            $inventorySchema.products[$i + $j].property_values += (GetEmptyPropertyValuesSchema)
            $inventorySchema.products[$i + $j].property_values[1].property_id = (GetProperty_id $var2list[$j].property_name)
            $inventorySchema.products[$i + $j].property_values[1].scale_id = $var2list[$j].scale_id
            $inventorySchema.products[$i + $j].property_values[1].property_name = $var2list[$j].property_name
            $inventorySchema.products[$i + $j].property_values[1].values[0] = $var2list[$j].value

            if($inventorySchema.products[$i + $j].property_values[0].property_id -eq $inventorySchema.products[$i + $j].property_values[1].property_id)
            {
                $inventorySchema.products[$i + $j].property_values[1].property_id = (GetProperty_id "CUSTOM2")
            }
        }
    }
    return $inventorySchema
}