Write-Host "Loading EtsyAPIUtilities..." -ForegroundColor Magenta

function NewDictionary() {
    return New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
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
function ConvertListingToUpdateFormat($listing)
{
    $inventory = $listing.inventory
    $baseScheme = GetListingSchema

    $list = [System.Collections.Generic.List[Object]]::new()
    

    foreach($product in $inventory.products)
    {
        $list.Add((GetProductScheme $product))
    }
    $baseScheme.products = $list.ToArray()

    return $baseScheme
}

<#
Used when adding variations to an item that only have a SINGLE variation.
#>
function AddSingleVariationInventoryToListing($listing, $property_name, $property_values, $property_id = 0, $price = $null, $quantity = $null)
{
    if($price -eq $null)
    {
        $price = $listing.price.amount / 100
    }

    if($quantity -eq $null)
    {
        $quantity = $listing.quantity
    }

    $productSchema = GetEmptyProductSchema
    $productSchema.offerings[0].price = $price
    $productSchema.offerings[0].quantity = $quantity
    $productSchema.offerings[0].is_enabled = $true

    #If the property_id is NOT 513, or 514 get the variation name string from the known table
    if($property_id -lt 513 -or $property_id -gt 514)
    {
       $property_id = $global:property_id.Get_Item($property_name)
    }

    $list = [System.Collections.Generic.List[string]]::new()

    foreach($i in $property_values)
    {
        $list.add($i)
    }

    $productSchema.property_values[0].property_id = $property_id
    $productSchema.property_values[0].property_name = $property_name
    $productSchema.property_values[0].values = $list.ToArray()

    #Remove value_ids for newly added properties because we don't need them.
    $productSchema.property_values | %{$_.psobject.members.remove('value_ids')}

    $list = [System.Collections.Generic.List[Object]]::new()
    
    foreach($product in $listing.inventory.products)
    {
        $list.Add((GetProductScheme $product))
    }
    $list.Add($productSchema)
    $listing.inventory.products = $list.ToArray()
}