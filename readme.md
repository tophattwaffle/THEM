# THEM - *The Horrible Etsy Manager*
This is a home brew solution to manage 1 or more Etsy shops with bulk actions. 

Why the name? By my own admission, this is *not* the best solution to Etsy shop management. I'm making this mostly because I wanted to learn PowerShell better and Etsy shop management was a problem I needed to solve.

## Current Use Cases
- Make bulk edits to variations in Excel and push them to Etsy
- Exporting shop inventories to CSV file (Variations)
- Tracking open orders for all shops using Home Assistant

## Planned Features
- Automated quantity "pegging" to reset and items inventory every so often.

How to get this running:

 1. Clone repo
 2. Get your Etsy API key and app setup.
    [Register app here](https://www.etsy.com/developers/your-apps)
 3. Inside your app configuration, you'll need to set a callback URL. Etsy will redirect you to this URL after you authorize your app against your Etsy account.
 4. Open `lib\EtsyAPIGlobalVars.ps1` and edit the `$global:redirectURL` variable to be a string that is your callback URL. (Mine is included as an example, but you likely won't be able to use it for your app since the callback domain and your app's domain must match.)
 5. *Optional* For simplicity, I've included my `auth.php` inside the `web` folder in the repo. This is where my callback URL is pointed to. You can use this file to easily get the Etsy authorization code and copy it to your clipboard after authorizing the Etsy app.
 6. Run `THEM.ps1`
 7. When prompted, provide your Etsy API key. The script will test communication with the Etsy API, if unsuccessful it will print the error.
 8. Once connected, you'll be given a prompt for what you'd like to do. Select `Add New Shop` and follow the prompts.
 9. You're all set! When you reload `THEM.ps1` it will test a connection to Etsy, and reload any previously saved shops if they exist.

Data is stored in your `Documents/EtsyAPI directory`. At the moment *no stored data is encrypted*. If you want to "default" the script, delete the stored XML data.

## Additional Information
There are various configuration options inside `Lib\EtsyAPIGlobalVars.ps1`
 - `$global:dontRefresh` is a `bool` variable that determines if shop data should be automatically refreshed on script load.
	 - The use case for this variable is for testing purposes to not constantly hammer the EtsyAPI for refreshes. You can manually refresh the shop data from the main menu.

 - `$global:DraftsOnly` is a `bool` that will make the `GetAllListings` call only pull listings in the `draft` sate.
	 - This is used for testing changes on listings that are not live.

 - `$global:redirectURL` is a `string` of your callback URL

 - `$global:saveLocation` is a `string` of a path for where all data should be stored.
 
 - `$global:settings.splitChar` is a value that will be saved in `EtsyAPIsettings.xml`. This char is used to split variations during inventory exports / imports. This char cannot be used in your variation strings. It is default of `;`

 ## Etsy ID tables
 Putting these here for quick reference later on. Etsy does not seem to have these documented.

| property_id     | Value       |
|-----------------|-------------|
| Primary color   | 200         |
| Secondary color | 52047899002 |
| CUSTOM1         | 513         |
| CUSTOM2         | 514         |
| Size            | 100         |
| Style           | 510			|

| scale_id        | Value       |
|-----------------|-------------|
| Inches          | 327         |

## How to bulk update inventories

1. Export your inventories to a CSV using the export function.
2. Open the `[shop_id]_inventory.csv`
3. Edit the inventories as needed. Be sure to follow the formatting as outlined below.
4. In the `Actions` column, set the action to `update` for each inventory to be updated.
5. From the main menu select update inventories.

## Update Inventory Formatting

Consider the following table:
| listing_id | quantity | title            | priScale_id | secScale_id | priVarName    | secVarName        | priVarValue0        | priVarValue1          | priVarValue2 | ... | secVarValue0 | secVarValue1 | secVarValue2 |
|------------|----------|------------------|-------------|-------------|---------------|-------------------|---------------------|-----------------------|--------------|-----|--------------|--------------|--------------|
| 1234       | 15       | Single Variation |             |             | Primary color |                   | Red                 | Black                 | Magenta      | ... |              |              |              |
| 9012       | 10       | Two Variations   |             |             | Primary Color | Secondary color   | Red                 | Black                 | Purple       | ... | Yellow       | Rose Gold    | Clear        |
| 5678       | 5        | Price on Primary |             |             | Custom Name   | Another Custom    | Blue;7              | Mint;6                | Yellow;8     | ... | Rose gold    | Beige        |              |
| 3456       | 6        | Price on Both    | 327         |             | Size          | Mounting Hardware | 6.5 x 4.5;8.49;None | 6.5 x 4.5;9.49;Screws |              | ... |              |              |              |

listing_id `1234` only has primary variations. Each variation has no cost associated with it.

listing_id `9012` has 2 variations. All combinations of these variations cost the same.

listing_id `5678` has primary variations as well as secondary variations. However the price for each item is determined by the primary variation. You specify the price for each variation by placing the price after the variation name separated by a `;` which looks like `[NAME];[PRICE]`for example, to have a variation of `Blue` that costs `7.49` you would enter: `Blue;7.49`. The `;` is the value determined by `$global:settings.splitChar` which you can read more about above if you need to change it.

listing_id `3456` has 2 variations with prices dependant on each variation. Editing these variations in this script is pretty dreadful, but it is supported. You won't use the `secVarValue#` columns for these, but everything is set in the `priVarValue#` column. This is done on purpose so you can easily see what you are doing. They are in the format of: `[PriVariation];[PRICE];[SecVariation]`. You **MUST MANUALLY** provide all possible combinations for variations that have price dependant on both variations. I personally find that listings like these are pretty uncommon (for my use case) so using the Etsy site for this is fine for me.

## Settings up Home Assistant Open Order Checking
*Honestly there should probably be a Home Assistant based solution for this task, but I already wrote this in PowerShell and I have a windows server.*

 1. In Home Assistant create input_number helpers for each shop to track.
 2. In Node-Red (required), create a webhook and copy the URL.
 3. After the Webhook node, add a "switch" to check the property `msg.payload.shop_id`.
 4. Create an output on `==` for each shop_id you're going to update.
 5. Put a call service after the switch and set domain to `input_number` service to `set_value` and specify your helper entity. Use `{"value":payload.openOrders}` as the data.
 6. From the `THEM.ps1` main menu, select `Set HA Webhook URL` and paste the URL in.
 7. Refresh Shop Data and the webhook will be automatically called.
 8. *Optional* You can launch the script with the parameter `"auto"` to have it automatically run, update open orders and post to the webhook. For this to work, make sure the settings files are able to be loaded. (You may need to edit the settings locations from the `Documents` folder depending on the user launching it.) I'm using a Task Scheduler task to handle this.
