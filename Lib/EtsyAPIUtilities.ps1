Write-Host "Loading EtsyAPIUtilities..." -ForegroundColor Magenta

function NewDictionary() {
    return New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
}

function NewStringList() {
    return New-Object 'System.Collections.Generic.List[string]]'
}

function SetValueByString($object, $key, $Value) {
    $p1, $p2 = $key.Split(".")
    if ($p2) { SetValue -object $object.$p1 -key $p2 -Value $Value }
    else { $object.$p1 = $Value }
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
Takes a listing and converts the structure into one that can be used
in the UpdateListingInventory call
#>
function ConvertListingToUpdateFormat($listing) {
    $inventory = $listing.inventory
    $baseScheme = GetListingSchema

    $list = [System.Collections.Generic.List[Object]]::new()
    

    foreach ($product in $inventory.products) {
        $list.Add((GetProductScheme $product))
    }
    $baseScheme.products = $list.ToArray()

    return $baseScheme
}

<#
Determines how many TYPES (Eg. Primary Color + Seconday Color vs Primary Color) variations a listing
#>
function GetAmountOfVariationTypes($listing) {
    return $listing.inventory.products[0].property_values.count
}

<#
Used when adding variations to an item that only have a SINGLE variation.
#>
function AddSingleVariationInventoryToListing($listing, $property_name, $property_values, $property_id = 0, $price = $null, $quantity = $null) {
    if ($price -eq $null) {
        $price = $listing.price.amount / 100
    }

    if ($quantity -eq $null) {
        $quantity = $listing.quantity
    }

    $productSchema = GetEmptyProductSchema
    $productSchema.offerings[0].price = $price
    $productSchema.offerings[0].quantity = $quantity
    $productSchema.offerings[0].is_enabled = $true

    #If the property_id is NOT 513, or 514 get the variation name string from the known table
    if ($property_id -lt 513 -or $property_id -gt 514) {
        $property_id = $global:property_id.Get_Item($property_name)
    }

    $list = [System.Collections.Generic.List[string]]::new()

    foreach ($i in $property_values) {
        $list.add($i)
    }

    $productSchema.property_values[0].property_id = $property_id
    $productSchema.property_values[0].property_name = $property_name
    $productSchema.property_values[0].values = $list.ToArray()

    #Remove value_ids for newly added properties because we don't need them.
    $productSchema.property_values | % { $_.psobject.members.remove('value_ids') }

    $list = [System.Collections.Generic.List[Object]]::new()
    
    foreach ($product in $listing.inventory.products) {
        $list.Add((GetProductScheme $product))
    }
    $list.Add($productSchema)
    $listing.inventory.products = $list.ToArray()
}


<#
Gets all variations from a listing and parses them into a sorted list.
#>
function GetAllVariationsFromListing($listing) {
    $list = [System.Collections.Generic.List[Object]]::new()

    $pricingProperties = $listing.inventory.price_on_property

    #Handle NO pricing variations. Parse each variation into it's own object and shove into list.
    if($pricingProperties.count -eq 0)
    {
        foreach ($product in $listing.inventory.products) {
            foreach ($prop_value in $product.property_values) {
                $list.Add(([NoPriceVariation]@{
                    property_name = $prop_value.property_name
                    value = $prop_value.values[0]
                }))
            }
        }
    }

    #Handle pricing on a single property!
    elseif($pricingProperties.count -eq 1)
    {
        foreach ($product in $listing.inventory.products) {
            
            $list.Add([SinglePriceVariation]@{
                price_on_property = $pricingProperties[0]
                property_name = $product.property_values[0].property_name
                value = $product.property_values[0].values[0]
                price = $product.offerings[0].price.amount / $product.offerings[0].price.divisor
            })

            #There is a 2nd variation on listing
            if($product.property_values.count -eq 2)
            {
                $list.Add([SinglePriceVariation]@{
                    price_on_property = $pricingProperties[0]
                    property_name = $product.property_values[1].property_name
                    value = $product.property_values[1].values[0]
                    price = $product.offerings[0].price.amount / $product.offerings[0].price.divisor
                })
            }
        }

        #If the price property does not match the property_name, null the price.
        foreach($i in $list)
        {
            $thisPropId = $global:property_id.Item($i.property_name)
            if($thisPropId -ne $i.price_on_property)
            {
                $i.price = $null
            }
        }
    }

    #Handle pricing when on BOTH properties
    #Safe to assume there are 2 variations since there is pricing on 2 props
    elseif($pricingProperties.count -eq 2)
    {
        foreach ($product in $listing.inventory.products) {
            $list.Add([DoublePriceVariation]@{
                property_name = $product.property_values[0].property_name
                value = $product.property_values[0].values[0]
                property_name2 = $product.property_values[1].property_name
                value2 = $product.property_values[1].values[0]
                price_on_property = $pricingProperties.ToArray()
                price = $product.offerings[0].price.amount / $product.offerings[0].price.divisor
            })
        }
    }
    
    #return based on the type.
    switch($list[0].GetType().Name)
    {
        #De dupe, sort output
        "NoPriceVariation"{
            return $list | Group-Object -Property 'property_name', 'value' | ForEach-Object { $_.Group[0] } | Sort-Object -Property 'property_name'
        }

        "SinglePriceVariation"{
            return $list | Group-Object -Property 'property_name', 'value' | ForEach-Object { $_.Group[0] } | Sort-Object -Property 'property_name'
        }

        #I don't think order matters for this one???
        "DoublePriceVariation"{
            return $list #| Group-Object -Property 'property_name', 'value' | ForEach-Object { $_.Group[0] } | Sort-Object -Property 'property_name'
        }
    }

    #Failure return null?
    return $null
}

class NoPriceVariation{
    [string]$property_name
    [string]$value
}

class SinglePriceVariation{
    [string]$property_name
    [string]$value
    [int]$price_on_property
    [nullable[float]]$price
}

class DoublePriceVariation{
    [string]$property_name
    [string]$value
    [string]$property_name2
    [string]$value2
    [int64[]]$price_on_property = [int64[]]::new(2)
    [float]$price
}