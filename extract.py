import sys, json, re
with open('$WIP', 'r', encoding='utf-8', errors='ignore') as f:
    html = f.read()
match = re.search(r'<script type=\"application/ld\+json\"[^>]*>(.*?)</script>', html, re.DOTALL)
if match:
    data = json.loads(match.group(1))
    if isinstance(data, dict) and '@graph' in data:
        for item in data.get('@graph', []):
            if item.get('@type') == 'Recipe' and 'nutrition' in item:
                print(json.dumps(item['nutrition']))
                sys.exit(0)