#!/usr/bin/env bash
# set -o pipefail

## Set base directory
ScriptDir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
WIP=$(mktemp)
ErrorLog=$ScriptDir/Scraped-Data.errors.txt

## Read URLs from CSV file
CSV_InFile="$1"
if [[ ! -f "$CSV_InFile" ]]; then
	echo "Error: Input CSV file not found: $CSV_InFile" >&2
	exit 1
fi
mapfile -t URLs < <(cat "$CSV_InFile")

OutFile=$ScriptDir/Scraped-Data.csv

## Define nutrition fields in order
NutritionFields=(
	"servingSize"
	"calories"
	"sugarContent"
	"sodiumContent"
	"fatContent"
	"saturatedFatContent"
	"transFatContent"
	"carbohydrateContent"
	"fiberContent"
	"proteinContent"
	"cholesterolContent"
)

## Function to escape CSV values (handle quotes and commas)
csv_escape() {
	local val="$1"
	# If value contains comma, quote, or newline, wrap in quotes and escape inner quotes
	if [[ "$val" =~ [,\"] || "$val" =~ $'\n' ]]; then
		val="\"${val//\"/\"\"}\""
	fi
	echo "$val"
}

## Function to split value and unit
## Input: "4.6 g" → Output: "4.6" "g"
split_value_unit() {
	local raw="$1"
	
	# Remove leading/trailing whitespace
	raw="${raw%% }"
	raw="${raw## }"
	
	# Try to match pattern: number (including decimals) + optional space + rest as unit
	if [[ $raw =~ ^([0-9.]+)[[:space:]]*(.*)$ ]]; then
		echo "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
	else
		# If no match, treat entire string as unit
		echo "" "$raw"
	fi
}

## Check for existing output file to support resume
declare -A ProcessedSlugs
if [[ -f "$OutFile" ]]; then
	# Read existing slugs (skip header line)
	while IFS=, read -r slug rest; do
		if [[ "$slug" != "slug" && -n "$slug" ]]; then
			ProcessedSlugs["$slug"]=1
		fi
	done < "$OutFile"
fi

## Write CSV header line (only if file is new)
if [[ ! -f "$OutFile" ]]; then
	header="slug"
	for field in "${NutritionFields[@]}"; do
		header+=",${field},${field}_unit"
	done
	echo "$header" > "$OutFile"
	> "$ErrorLog"  # Clear error log
fi

## Initialize counters
TotalCount=${#URLs[@]}
ProcessedCount=0
SkippedCount=0
ErrorCount=0
StartTime=$(date +%s)

## Curl each URL
for URL in "${URLs[@]}"; do
	((ProcessedCount++))
	
	# Show progress every 50 URLs
	if (( ProcessedCount % 50 == 0 )); then
		echo "Processing: $ProcessedCount / $TotalCount"
	fi
	
	## Extract slug from URL (last path component before trailing slash)
	slug="${URL##*/}"     # Get everything after last /
	slug="${slug%%\?*}"   # Remove query string if present
	slug="${slug%%#*}"    # Remove fragment if present
	slug="${slug%%/}"     # Remove trailing slash
	
	# Skip if already processed
	if [[ -n "${ProcessedSlugs[$slug]}" ]]; then
		((SkippedCount++))
		continue
	fi
	
	## Curl the URL and save to work file
	if ! curl -s -i "$URL" > "$WIP" 2>&1; then
		echo "$URL,CURL_FAILED" >> "$ErrorLog"
		((ErrorCount++))
		sleep 5
		continue
	fi
	
	## Extract nutrition JSON from HTML
	# Extract the entire JSON-LD script content, then parse for nutrition object
	# First, get the script tag content as a single line
	json_ld_content=$(sed -n 's/.*type="application\/ld+json"[^>]*>\s*\(.*\)<\/script>.*/\1/p' "$WIP" | tr '\n' ' ')
	
	if [[ -z "$json_ld_content" ]]; then
		# No JSON-LD found
		echo "$URL,NO_JSON_LD" >> "$ErrorLog"
		row="$(csv_escape "$slug")"
		for field in "${NutritionFields[@]}"; do
			row+=",,"
		done
		echo "$row" >> "$OutFile"
		((ErrorCount++))
		sleep 5
		continue
	fi
	
	# Try to extract nutrition object from the JSON
	# The JSON-LD might be an array or single object, and nutrition might be nested
	nutrition_json=$(echo "$json_ld_content" | jq -r '(if type == "array" then .[] else . end) | select(.nutrition != null) | .nutrition' 2>/dev/null || true)
	
	if [[ -z "$nutrition_json" ]]; then
		# No nutrition data found in JSON-LD
		echo "$URL,NO_NUTRITION_DATA" >> "$ErrorLog"
		# Write slug with blank fields
		row="$(csv_escape "$slug")"
		for field in "${NutritionFields[@]}"; do
			row+=",,"
		done
		echo "$row" >> "$OutFile"
		((ErrorCount++))
		sleep 5
		continue
	fi
	
	# Parse each field
	declare -A FieldValues
	for field in "${NutritionFields[@]}"; do
		value=$(echo "$nutrition_json" | jq -r ".$field // \"\"" 2>/dev/null || echo "")
		FieldValues["$field"]="$value"
	done
	
	# Build CSV row
	row="$(csv_escape "$slug")"
	for field in "${NutritionFields[@]}"; do
		raw_value="${FieldValues[$field]}"
		if [[ -n "$raw_value" && "$raw_value" != "null" ]]; then
			# Split value and unit
			read -r value unit <<< "$(split_value_unit "$raw_value")"
			row+="," "$(csv_escape "$value")" "," "$(csv_escape "$unit")"
		else
			row+=",,"
		fi
	done
	
	echo "$row" >> "$OutFile"
	
	## Wait to avoid bot detection
	sleep 5
done

## Cleanup
rm -f "$WIP"

## Print summary
EndTime=$(date +%s)
ElapsedTime=$((EndTime - StartTime))
echo ""
echo "========== Scrape Complete =========="
echo "Total URLs: $TotalCount"
echo "Processed: $ProcessedCount"
echo "Skipped (resume): $SkippedCount"
echo "Errors/Missing: $ErrorCount"
echo "Time elapsed: $(printf '%d:%02d:%02d' $((ElapsedTime/3600)) $((ElapsedTime%3600/60)) $((ElapsedTime%60)))"
echo "Output: $OutFile"
echo "Errors log: $ErrorLog"