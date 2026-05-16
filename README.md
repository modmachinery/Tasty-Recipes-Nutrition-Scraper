# Tasty Recipes Nutrition Data Scraper
If you host a recipe site and use the *Tasty Recipes* plugin to provide nutrition data, your data is stored in their database and there is currently no official option available to export it. This script provides a quick and reasonable solution.

## Quick Note
This script is intended to be used on a personal basis, on your own data, and with the sole purpose of allowing you to collect and store your data locally.

It is unknown at this time if any nutrition software allows for import of the data this script creates, however a programmer would easily be able to work with the data for a personal solution.

## 🏁 Getting Started
Create a CSV (Comma Separated Values) file of URLs, one link per line and with a header. View the `template.csv` file for an example.

I recommend using the [Export All URLs](https://wordpress.org/plugins/export-all-urls/) WordPress Plugin to export your posts to a CSV file.

If you don't already have `git`, use (or install) [Homebrew](https://brew.sh/), the run:
```bash
brew install git
```
Launch a Terminal and clone this repository:
```bash
git clone https://github.com/modmachinery/tasty-recipes-nutrition-scraper.git
```
Adding the exported CSV file to the cloned repository directory can simplify the execution command.

## 👩🏻‍💻 Using the Script
From the Terminal, change directories to the location you cloned the repo; example:
```bash
cd tasty-recipes-nutrition-scraper/
```
Execute the script and provide the location of your CSV file. If you moved it to your clone of the repo:
```bash
./scrape-nutrition-data.sh your-file.csv
```
Otherwise provide the relative or full path to the file; example:
```bash
./scrape-nutrition-data.sh ~/Downloads/Site\ Data/your-file.csv
```
## ⬇️ How It Works
The script uses the `curl` command to navigate to each web address, scrapes out the raw data as it's presented in the browser, extracts each individual nutrition element, and exports it to a CSV file with headers to identify what each data point represents.

The data gets saved to a file in your local repository dirtoory, it will be named: `scraped-data-output.csv`. Once the script has completed you can open this file in a spreadsheet application such as **Microsoft Excel** or **Apple Numbers** to view it. It can be imported to a **Google Sheet** for easy sharing.

Make sure to keep a copy of the original CSV file, as these applications will convert the imported data to their own native formats.

### Extras
If you provided URLs that do not contain any *Tasty Recipes* nutrition data, the URL will get logged to a file in the `/log` folder. The script will continue on to the next URL in the list.