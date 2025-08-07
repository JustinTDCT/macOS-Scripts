#!/bin/bash

INPUT_DIR="${1:-.}"

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
  OUTFILE="${INPUT_DIR}/${BASENAME}.json"

  ((COUNT++))
  echo "🔄 [$COUNT/$TOTAL] Processing: $BASENAME.evtx"

  evtx_dump "$FILEPATH" > "$OUTFILE" 2>/dev/null &
  CMD_PID=$!

  spinner $CMD_PID
  wait $CMD_PID
  STATUS=$?

  if [[ $STATUS -eq 0 ]]; then
    printf "✅ [%d/%d] Done: %s → %s\n\n" "$COUNT" "$TOTAL" "$BASENAME.evtx" "$BASENAME.json"
  else
    printf "❌ [%d/%d] Error: Failed to process %s\n\n" "$COUNT" "$TOTAL" "$BASENAME.evtx"
  fi
done

echo "🎉 All done! Processed $TOTAL .evtx file(s)."
