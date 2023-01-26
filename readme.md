# THEM - *The Horrible Etsy Manager*
This is a home brew solution to manage 1 or more Etsy shops with bulk actions. 

Why the name? By my own admission, this is *not* the best solution to Etsy shop management. I'm making this mostly because I wanted to learn PowerShell better and Etsy shop management was a problem I needed to solve.

Currently this does not do much but connect to Etsy and make some Get requests to pull shop data. I'm currently working on actual bulk management features, but Etsy's V3 API is trash to work with so this is taking some time.

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

## Additional Information - 
There are various configuration options inside `Lib\EtsyAPIGlobalVars.ps1`
 - `$global:dontRefresh` is a `bool` variable that determines if shop data should be automatically refreshed on script load.
	 - The use case for this variable is for testing purposes to not constantly hammer the EtsyAPI for refreshes. You can manually refresh the shop data from the main menu.

 - `$global:DraftsOnly` is a `bool` that will make the `GetAllListings` call only pull listings in the `draft` sate.
	 - This is used for testing changes on listings that are not live.

 - `$global:redirectURL` is a `string` of your callback URL

 - `$global:saveLocation` is a `string` of a path for where all data should be stored.