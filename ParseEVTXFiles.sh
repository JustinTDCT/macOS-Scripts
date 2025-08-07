#!/bin/bash

# ───────────────────────────────────────────────────────────────
# Setup
# ───────────────────────────────────────────────────────────────

echo "🔍 Initializing..."

# Create virtual environment if missing
if [ ! -d ".evtx" ]; then
  echo "🔧 Creating virtual environment in .evtx..."
  python3 -m venv .evtx
fi

# Try to activate the venv
if [ -f ".evtx/bin/activate" ]; then
  source .evtx/bin/activate
else
  echo "❌ ERROR: Cannot activate virtual environment — '.evtx/bin/activate' not found."
  exit 1
fi

# Install packages if missing
pip install --quiet --disable-pip-version-check xmltodict pandas

# Create output folders if missing
mkdir -p evtx xml csv evtx_empty

# ───────────────────────────────────────────────────────────────
# Spinner Setup
# ───────────────────────────────────────────────────────────────
spinner="/-\|"
spin() {
  echo -ne "\b${spinner:i++%${#spinner}:1}"
}

# ───────────────────────────────────────────────────────────────
# Processing Loop
# ───────────────────────────────────────────────────────────────

EVTX_FILES=(*.evtx)
TOTAL=${#EVTX_FILES[@]}

echo "🔍 Found $TOTAL .evtx file(s) in '.'"

i=1
for filepath in "${EVTX_FILES[@]}"; do
  base="$(basename "$filepath" .evtx)"
  stage1="${base}_stage1.xml"
  stage2="${base}_stage2.xml"
  final="${base}_final.xml"
  csvfile="${base}.csv"

  echo ""
  echo "📁 [$i/$TOTAL] Processing: $filepath"

  # ────────────────────────
  # Stage 1: Convert EVTX → XML
  # ────────────────────────
  echo -ne "  🧾 Stage 1: evtx_dump → $stage1 [/] Working..."
  if ! evtx_dump "$filepath" > "$stage1" 2>/dev/null; then
    echo -e "\r  ❌ Stage 1 failed (conversion error)"
    rm -f "$stage1"
    ((i++))
    continue
  fi

  if [ ! -s "$stage1" ]; then
    echo -e "\r  ❌ Stage 1 failed (empty file)"
    rm -f "$stage1"
    mv "$filepath" ./evtx_empty/
    ((i++))
    continue
  fi
  echo -e "\r  ✅ Stage 1 complete"

  # ────────────────────────
  # Stage 2: Clean XML
  # ────────────────────────
  echo -ne "  🧼 Stage 2: Cleaning → $stage2 [/] Working..."
  sed -E 's/^Record ([0-9]+)/<!-- Record \1 -->/; s/^<\?xml.*\?>/<!-- & -->/' "$stage1" > "$stage2"
  echo -e "\r  ✅ Stage 2 complete"

  # ────────────────────────
  # Stage 3: Wrap in <Events> → Final XML
  # ────────────────────────
  echo -ne "  📦 Stage 3: Wrapping → $final [/] Working..."
  echo "<Events>" > "$final"
  cat "$stage2" >> "$final"
  echo "</Events>" >> "$final"
  echo -e "\r  ✅ Stage 3 complete"

  # ────────────────────────
  # Stage 4: Convert XML → CSV
  # ────────────────────────
  echo -ne "  📄 Stage 4: Convert → $csvfile [/] Working..."
  python3 -c "
import xmltodict, pandas as pd
try:
    with open('$final') as f:
        events = xmltodict.parse(f.read()).get('Events', {}).get('Event', [])
        if not isinstance(events, list): events = [events]
        rows = []
        for e in events:
            r = {}
            s = e.get('System', {})
            r['EventID'] = s.get('EventID', '')
            r['Provider'] = s.get('Provider', {}).get('@Name', '')
            r['TimeCreated'] = s.get('TimeCreated', {}).get('@SystemTime', '')
            r['Computer'] = s.get('Computer', '')
            d = e.get('EventData', {}).get('Data', [])
            if isinstance(d, dict):
                r[d.get('@Name', 'Data')] = d.get('#text', '')
            elif isinstance(d, list):
                for item in d:
                    r[item.get('@Name', 'Data')] = item.get('#text', '')
            rows.append(r)
        pd.DataFrame(rows).to_csv('$csvfile', index=False)
except Exception:
    exit(1)
" 2>/dev/null

  if [ -f "$csvfile" ] && [ -s "$csvfile" ]; then
    echo -e "\r  ✅ Stage 4 complete"
  else
    echo -e "\r  ❌ Stage 4 failed (could not convert to CSV)"
  fi

  # ────────────────────────
  # Move & Cleanup
  # ────────────────────────
  mv "$filepath" ./evtx/
  mv "$final" ./xml/ 2>/dev/null
  mv "$csvfile" ./csv/ 2>/dev/null
  rm -f "$stage1" "$stage2"
  mv *.evtx ./evtx_empty
  ((i++))
done

# ───────────────────────────────────────────────────────────────
# Cleanup
# ───────────────────────────────────────────────────────────────
deactivate
echo ""
echo "✅ All done. Virtual environment deactivated."
