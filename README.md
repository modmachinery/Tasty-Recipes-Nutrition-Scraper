# Tasty Recipes Nutrition Scraper
If you host a recipe site on the WordPress platform and use the **Tasty Recipes** plugin to provide nutrition data to your audience, your nutrition data is fully stored on their database. At the time this was written there is no official option available to download a copy of your data for your own records.

This script provides a quick and reasonable solution to this problem.

## ⬇️  How It Works
The script uses a simple `curl` command to scrape the page code from each provided URL. It extracts the individual nutrition data element from the recipe card and exports it to a CSV file. The file is created with headers for identifying each data point.

The CSV file containing the nutrition data will be generated inside the directory of the repository. Once the script has completed parsing each provided URL you can open the CSV file in any spreadsheet application like **Microsoft Excel**, **Apple Numbers**, or **Google Sheets** to view it.

## 📝  Author's Notes: Please Read
- **This script is intended to be used on a personal basis, on your own data, and with the sole purpose of allowing you to collect and store your own data locally.**
- It is unknown at this time if any existing third-party software allows for the import of this data. With that being said, any decent programmer should easily be able to work with the data to create a personalized solution for your needs.

## 🏁  Getting Started
I recommend using the **[Export All URLs](https://wordpress.org/plugins/export-all-urls/) WordPress Plugin** to export all Permalinks (the full public URLs) of your recipe posts to a CSV (Comma Separated Values) file. The file should be formatted to have one URL per line and with a header.

View the included `template.csv` file as an example:

```csv
PERMALINK
https://your-site-url.org/your-recipe-1.html
https://your-site-url.org/your-recipe-2.html
```

### ⤵️  Clone this Git Repo
If you don't already have `git`, use (or install) [Homebrew](https://brew.sh/), and run:

```bash
brew install git
```

Launch the **Terminal** application and clone this repository from Git:

```bash
git clone https://github.com/modmachinery/tasty-recipes-nutrition-scraper.git
```

Moving or copying the CSV file into the directory of the cloned repository will simplify the execution command.

## 👩🏻‍💻 Execute the Script
Change directories to the location you cloned the repository; example:

```bash
cd tasty-recipes-nutrition-scraper
```

Execute the script and provide the location of your CSV file. If you placed the file in your local clone of this repo:

```bash
./scrape-nutrition-data.sh your-file.csv
```

Otherwise provide the relative or full path to the file; example:

```bash
./scrape-nutrition-data.sh ~/Downloads/Site_Data/your-file.csv
```

As mentioned above, the CSV file will spawn in the repo directory– it will be named: `scraped-data-output.csv`.

Make sure to create a copy of the CSV file– many Spreadsheet applications will convert the imported data to their own proprietary formats. The CSV format is most commonly used for exporting/importing to another platform or database.

---
*AI was used only for debugging purposes; all code otherwise hand-typed by a human.*
