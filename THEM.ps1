# region Include required files
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\Lib\EtsyAPIGlobalVars.ps1")
    . ("$ScriptDirectory\Lib\EtsyAPIAuthHandler.ps1")
    . ("$ScriptDirectory\Lib\EtsyAPICalls.ps1")
    . ("$ScriptDirectory\Lib\EtsyAPIRequestHandlers.ps1")
    . ("$ScriptDirectory\Lib\EtsyAPIUtilities.ps1")
    . ("$ScriptDirectory\Lib\EtsyAPIJsonSchemas.ps1")
    . ("$ScriptDirectory\Lib\THEMFunctions.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" -ForegroundColor Red
    Write-Host $_
    exit
}
#endregion

function ExportListings() {
    foreach ($shop in $global:allShops) {

    }
}

function UpdateVariations() {

}

#Starting up the script...
Init


$testList = $global:allShops[0].allListings[3]

$variations = GetAllVariationsFromListing $testList

$variations = [System.Collections.Generic.List[Object]]::new()

$variations += [NoPriceVariation]@{
    property_name = "Size"
    value = "6"
    scale_id = 327
}
$variations += [NoPriceVariation]@{
    property_name = "Size"
    value = "9"
    scale_id = 327
}

$l = CreateUpdateListingInventoryFromList $testlist $variations


$json = ConvertTo-Json $l -Depth 99

$res = UpdateListingInventory $testList.listing_id $json $global:allShops[0].accessToken
$res


#Main loop for program.
while ($true) {
    MainMenu
}