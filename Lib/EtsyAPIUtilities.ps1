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
Determines how many TYPES (Eg. Primary Color + Seconday Color vs Primary Color) variations a listing
#>
function GetAmountOfVariationTypes($listing) {
    return $listing.inventory.products[0].property_values.count
}

<#
Gets all variations from a listing and parses them into a sorted list.
#>
function GetAllVariationsFromListing($listing) {
    $list = [System.Collections.Generic.List[Object]]::new()

    $pricingProperties = $listing.inventory.price_on_property

    #Handle NO pricing variations. Parse each variation into it's own object and shove into list.
    if ($pricingProperties.count -eq 0) {
        foreach ($product in $listing.inventory.products) {
            foreach ($prop_value in $product.property_values) {
                $list.Add(([NoPriceVariation]@{
                            property_name = $prop_value.property_name
                            value         = $prop_value.values[0]
                        }))
            }
        }
    }

    #Handle pricing on a single property!
    elseif ($pricingProperties.count -eq 1) {
        foreach ($product in $listing.inventory.products) {
            
            $list.Add([SinglePriceVariation]@{
                    price_on_property = $pricingProperties[0]
                    property_name     = $product.property_values[0].property_name
                    value             = $product.property_values[0].values[0]
                    price             = $product.offerings[0].price.amount / $product.offerings[0].price.divisor
                })

            #There is a 2nd variation on listing
            if ($product.property_values.count -eq 2) {
                $list.Add([SinglePriceVariation]@{
                        price_on_property = $pricingProperties[0]
                        property_name     = $product.property_values[1].property_name
                        value             = $product.property_values[1].values[0]
                        price             = $product.offerings[0].price.amount / $product.offerings[0].price.divisor
                    })
            }
        }

        #If the price property does not match the property_name, null the price.
        foreach ($i in $list) {
            $thisPropId = $global:property_id.Item($i.property_name)
            if ($thisPropId -ne $i.price_on_property) {
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
                    price_on_property = $pricingProperties.ToArray()
                    price             = $product.offerings[0].price.amount / $product.offerings[0].price.divisor
                })
        }
    }
    
    #return based on the type.
    switch ($list[0].GetType().Name) {
        #De dupe, sort output
        "NoPriceVariation" {
            return $list | Group-Object -Property 'property_name', 'value' | ForEach-Object { $_.Group[0] } | Sort-Object -Property 'property_name'
        }

        "SinglePriceVariation" {
            return $list | Group-Object -Property 'property_name', 'value' | ForEach-Object { $_.Group[0] } | Sort-Object -Property 'property_name'
        }

        #I don't think order matters for this one???
        "DoublePriceVariation" {
            return $list #| Group-Object -Property 'property_name', 'value' | ForEach-Object { $_.Group[0] } | Sort-Object -Property 'property_name'
        }
    }

    #Failure return null?
    return $null
}

class NoPriceVariation {
    [string]$property_name
    [string]$value
    [float]$price
}

class SinglePriceVariation {
    [string]$property_name
    [string]$value
    [int]$price_on_property
    [nullable[float]]$price
}

class DoublePriceVariation {
    [string]$property_name
    [string]$value
    [string]$property_name2
    [string]$value2
    [int64[]]$price_on_property = [int64[]]::new(2)
    [float]$price
}

function CreateUpdateListingInventoryFromList($product, $list) {
    #Determine the number of variations in the list.
    $variationNames = [System.Collections.Generic.List[String]]::new()
    foreach ($i in $list) {
        $variationNames.Add($i.property_name)
    }
    $variationNames = $variationNames | Select-Object -Unique

    switch ($list[0].GetType().Name) {
        #De dupe, sort output
        "NoPriceVariation" {
            #Single variation
            if ($variationNames.count -eq 1) {
                $result = CreateJsonSingleVariationNoPricing $product $list
            }
            elseif ($variationNames.count -eq 2) {

            }
            
        }

        "SinglePriceVariation" {
            
        }

        #I don't think order matters for this one???
        "DoublePriceVariation" {
            
        }
    }

    return $result
}

<#
Provided with a product and a list of SINGLE variations (Eg. Only Primary color)
Returns an inventory schema that can be sent with UpdateListingInventory call
#>
function CreateJsonSingleVariationNoPricing($product, $list) {
    $inventorySchema = GetInventorySchema $product
    foreach ($i in $list) {
        $productSchema = GetEmptyProductSchema

        $productSchema.property_values += (GetEmptyPropertyValuesSchema)

        $productSchema.sku = if($null -eq $product.sku) {""} else {$product.sku}
        $productSchema.property_values[0].property_id = ($global:property_id.Item($i.property_name))
        $productSchema.property_values[0].scale_id = $null #TODO: Handle scale_Id
        $productSchema.property_values[0].property_name = $i.property_name
        $productSchema.property_values[0].values[0] = $i.value

        $productSchema.offerings[0].price = $product.price.amount / $product.price.divisor
        $productSchema.offerings[0].quantity = $product.quantity
        $productSchema.offerings[0].is_enabled = $true

        #Always strip value IDs
        $productSchema.property_values | %{$_.psobject.members.remove('value_ids')}

        $inventorySchema.products += $productSchema
    }

    return $inventorySchema
}