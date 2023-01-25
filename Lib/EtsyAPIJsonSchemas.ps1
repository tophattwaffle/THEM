Write-Host "Loading EtsyAPIJsonSchemas..." -ForegroundColor Magenta

$global:property_id = @{
  "Primary color"  = 200
  "Seconday color" = 52047899002
  "CUSTOM1"        = 513
  "CUSTOM2"        = 514
  "Size"           = 100

}

function GetListingSchema($listing) {
  $schema = @'
    {
        "products": [],
        "price_on_property": [],
        "quantity_on_property": [],
        "sku_on_property": []
      }
'@
  $json = ConvertFrom-Json $schema
  $json.price_on_property = $listing.price_on_property
  $json.quantity_on_property = $listing.quantity_on_property
  $json.sku_on_property = $listing.quantity_on_property

  return $json
}

function GetEmptyProductSchema() {
  $schema = @'
    {
        "sku": "",
        "property_values": [
        ],
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

  $json.property_values += (GetEmptyPropertyValuesSchema)

  return $json
}

function GetEmptyPropertyValuesSchema() {
  $schema = @'
  {
    "property_id": null,
    "value_ids": [
      null
    ],
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


function GetProductScheme($product) {
  $json = GetEmptyProductSchema

  $json.sku = $product.sku
  $json.property_values[0].property_id = $product.property_values[0].property_id
  $json.property_values[0].value_ids = $product.property_values[0].value_ids
  $json.property_values[0].scale_id = $product.property_values[0].scale_id
  $json.property_values[0].property_name = $product.property_values[0].property_name
  $json.property_values[0].values = $product.property_values[0].values

  if ($product[0].offerings.price.amount -ne $null) {
    $json.offerings[0].price = [float]$product[0].offerings.price.amount / 100
  }
  else {
    $json.offerings[0].price = [float]$product[0].offerings.price
  }
  $json.offerings[0].quantity = $product[0].offerings.quantity
  $json.offerings[0].is_enabled = $product[0].offerings.is_enabled

  if ($json.offerings[0].price -eq $null) {
    write-host "t"
  }
  return $json
}