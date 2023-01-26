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

#Main loop for program.
while ($true) {
    MainMenu
}