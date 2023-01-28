Write-Host "Loading EtsyAPIJsonSchemas..." -ForegroundColor Magenta

$global:property_id = @{
  "Primary color"  = 200
  "Secondary color" = 52047899002
  "CUSTOM1"        = 513
  "CUSTOM2"        = 514
  "Size"           = 100
}

function GetProperty_id($string)
{
  foreach($i in $global:property_id.Keys)
  {
    if($i.contains($string)) {$returnVar = $global:property_id.Item($i)}
  }

  if($null -eq $returnVar)
  {
    $returnVar = $global:property_id.Item("CUSTOM1")
  }

  return $returnVar
}

function GetInventorySchema($listing) {
  $schema = @'
    {
        "products": [],
        "price_on_property": [],
        "quantity_on_property": [],
        "sku_on_property": []
      }
'@
  $json = ConvertFrom-Json $schema
  $json.price_on_property = $listing.inventory.price_on_property
  $json.quantity_on_property = $listing.inventory.quantity_on_property
  $json.sku_on_property = $listing.inventory.quantity_on_property

  return $json
}

function GetEmptyProductSchema() {
  $schema = @'
    {
        "sku": "",
        "property_values": [],
        "offerings": [
          {
            "price": null,
            "quantity": null,
            "is_enabled": true
          }
        ]
      }
'@
  $json = ConvertFrom-Json $schema
  return $json
}

function GetEmptyPropertyValuesSchema() {
  $schema = @'
  {
    "property_id": null,
    "scale_id": null,
    "property_name": "",
    "values": [
      ""
    ]
  }
'@

$json = ConvertFrom-Json $schema
return $json
}