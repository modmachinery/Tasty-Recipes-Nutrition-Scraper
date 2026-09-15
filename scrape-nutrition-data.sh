#!/usr/bin/env bash
# set -o pipefail

## Set base directory
ScriptDir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
WIP=$(mktemp)
ErrorLog=$ScriptDir/log/no-data.csv

## Read URLs from CSV file
CSV_InFile="$1"
if [[ ! -f "$CSV_InFile" ]]; then
	echo "Error: Input CSV file not found: $CSV_InFile" >&2
	exit 1
fi
mapfile -t URLs < <(tail -n +2 "$CSV_InFile" | grep -v '^[[:space:]]*$')

OutFile=$ScriptDir/scraped-data-output.csv
Extract=$ScriptDir/extract.py

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
	printf '%s\n' "${header}" > "$OutFile"
	: > "$ErrorLog"  # Clear error log
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
		printf 'Processing: %s / %s\n' \
			"${ProcessedCount}" "${TotalCount}"
	fi
	
	## Extract slug from URL (last path component before trailing slash)
	if [[ -z "$URL" ]]; then
		continue
	fi
	# Remove trailing slash first, then extract last path component
	slug="${URL%/}"       # Remove trailing slash
	slug="${slug##*/}"    # Get everything after last /
	slug="${slug%%\?*}"   # Remove query string if present
	slug="${slug%%#*}"    # Remove fragment if present
	
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
	
	## Extract nutrition JSON from HTML using Python for reliable parsing
	json_ld_content=$(
		python3 -c "$Extract" 2>/dev/null || true
	)
	
	if [[ -z "$json_ld_content" ]]; then
		# No nutrition data found
		echo "$URL,NO_NUTRITION_DATA" >> "$ErrorLog"
		row="$(csv_escape "$slug")"
		for field in "${NutritionFields[@]}"; do
			row+=",,"
		done
		echo "$row" >> "$OutFile"
		((ErrorCount++))
		sleep 5
		continue
	fi

	# Parse each field from nutrition object 
	# (already extracted and JSON-formatted by Python)
	declare -A FieldValues
	for field in "${NutritionFields[@]}"; do
		value=$(
			echo "$json_ld_content" \
			| jq -r ".$field // \"\"" 2>/dev/null \
			|| echo ""
		)
		FieldValues["$field"]="$value"
	done
	
	# Build CSV row
	row="$(csv_escape "$slug")"
	for field in "${NutritionFields[@]}"; do
		raw_value="${FieldValues[$field]}"
		if [[ -n "$raw_value" && "$raw_value" != "null" ]]; then
			# Split value and unit
			read -r value unit <<< "$(split_value_unit "$raw_value")"
			row+=",$(csv_escape "$value"),$(csv_escape "$unit")"
		else
			row+=",,"
		fi
	done
	
	printf '%s\n' "${row}" >> "$OutFile"
	
	## Wait to avoid bot detection
	sleep 5
done

## Cleanup
rm -f "$WIP"

## Print summary
EndTime=$(date +%s)
ElapsedTime=$((EndTime - StartTime))
printf '\n%s\n' "========== Scrape Complete =========="
printf 'Total URLs: %s\n' "${TotalCount}"
printf 'Processed: %s\n' "${ProcessedCount}"
printf 'Skipped (resume): %s\n' "${SkippedCount}"
printf 'Errors/Missing: %s\n' "${ErrorCount}"
printf "Time Elapsed: "
printf '%d:%02d:%02d\n' \
	"$((ElapsedTime/3600))" \
	"$((ElapsedTime%3600/60))" \
	"$((ElapsedTime%60)))"
printf 'Output: %s\n' "${OutFile}"
printf 'Missing Data/Error Log: %s' "${ErrorLog}"