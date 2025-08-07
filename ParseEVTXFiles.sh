#!/bin/bash

INPUT_DIR="${1:-.}"

# Create output folders
mkdir -p "$INPUT_DIR/evtx"
mkdir -p "$INPUT_DIR/xml"
mkdir -p "$INPUT_DIR/csv"  # Reserved for future CSV output

# Collect .evtx files into an array
FILES=()
while IFS= read -r -d '' file; do
  FILES+=("$file")
done < <(find "$INPUT_DIR" -maxdepth 1 -type f -name "*.evtx" -print0)

TOTAL=${#FILES[@]}

if [[ $TOTAL -eq 0 ]]; then
  echo "❌ No .evtx files found in $INPUT_DIR"
  exit 1
fi

echo "🔍 Found $TOTAL .evtx files in '$INPUT_DIR'"
echo

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while ps -p $pid > /dev/null 2>&1; do
    local temp=${spinstr#?}
    printf " [%c] Working...\r" "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
}

COUNT=0
for FILEPATH in "${FILES[@]}"; do
  BASENAME=$(basename "$FILEPATH" .evtx)
  CLEANED="${BASENAME}_cleaned.xml"
  WRAPPED="${BASENAME}_wrapped.xml"
  FINAL="${BASENAME}_final.xml"

  ((COUNT++))
  echo "🔄 [$COUNT/$TOTAL] Processing: $BASENAME.evtx"

  # Step 1: Convert EVTX to raw XML
  evtx_dump "$FILEPATH" > "${BASENAME}.xml" 2>/dev/null &
  CMD_PID=$!
  spinner $CMD_PID
  wait $CMD_PID
  STATUS=$?

  if [[ $STATUS -ne 0 ]]; then
    echo "❌ Failed to convert $BASENAME.evtx"
    continue
  fi

  # Step 2: Comment out Record and XML declarations
  sed -E 's/^Record ([0-9]+)/<!-- Record \1 -->/; s/^<\?xml.*\?>/<!-- & -->/' "${BASENAME}.xml" > "$CLEANED"

  # Step 3: Wrap with root <Events> element
  {
    echo "<Events>"
    cat "$CLEANED"
    echo "</Events>"
  } > "$WRAPPED"

  # Step 4: Format using xmllint
  xmllint --format "$WRAPPED" > "$FINAL" 2>/dev/null

  # Step 5: Move outputs
  mv "$FILEPATH" "$INPUT_DIR/evtx/"
  mv "$FINAL" "$INPUT_DIR/xml/"

  # Step 6: Clean up temp files
  rm -f "${BASENAME}.xml" "$CLEANED" "$WRAPPED"

  echo "✅ [$COUNT/$TOTAL] Complete: $BASENAME.evtx → xml/$FINAL"
  echo
done

echo "🎉 All done! Processed $TOTAL .evtx file(s)."
