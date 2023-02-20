#Stop transcript if running, then start a new one. Transcript good for logging when running headless.
try {
    stop-transcript | out-null
}
catch [System.InvalidOperationException] {}
$transPath = "$PSScriptroot\THEM.txt"
Start-Transcript -Path $transPath


# region Include required files
$global:runMode = $args[0]
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
    Write-Host $_ #print error
    exit
}
#endregion
#Starting up the script...
Init

#Main loop for interactive program.
if ($global:runMode -ne "auto") {

    while ($true) {
        MainMenu
    }
}
#Automate actions!
elseif ($global:runMode -eq "auto") {
    Write-host "Auto mode!"
    if ($global:dontRefreshOnLoad) {
        RefreshAllShops #Refresh all shops so the webhooks can be published.
    }
}