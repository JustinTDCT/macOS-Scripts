#!/bin/bash

# 🧼 Clear screen
clear

# 📌 Banner
echo "🔍 Chainsaw EVTX Scan Script"
echo "📦 Current directory: $(pwd)"
echo ""

# 🛠 Show Chainsaw version
if ! command -v chainsaw &>/dev/null; then
    echo "❌ Chainsaw is not installed or not in PATH."
    exit 1
fi

CHAINSAW_VERSION=$(chainsaw --version)
echo "🛠  Using Chainsaw version: $CHAINSAW_VERSION"
echo ""

# 📁 Set up folders
BASE_DIR="$(pwd)"
EVTX_DIR="$BASE_DIR"
OUTPUT_DIR="$BASE_DIR/output"
SIGMA_DIR="$HOME/sigma-rules"
SIGMA_RULES="$SIGMA_DIR/rules/windows"
MAPPING_FILE="/usr/local/bin/mappings/sigma-event-logs-all.yml"

# 📥 Check for mapping file
if [ ! -f "$MAPPING_FILE" ]; then
    echo "❌ Mapping file not found at: $MAPPING_FILE"
    echo "➡️  Please make sure Chainsaw mappings are installed."
    exit 1
fi

# 📥 Check Sigma rules (auto update if Git repo, otherwise download)
if [ -d "$SIGMA_DIR/.git" ]; then
    echo "🔄 Updating Sigma rules in $SIGMA_DIR ..."
    git -C "$SIGMA_DIR" pull --quiet
elif [ -d "$SIGMA_RULES" ]; then
    echo "📂 Sigma rules already present in $SIGMA_RULES (non-git folder)"
else
    echo "⬇️  Downloading latest Sigma rules to $SIGMA_DIR ..."
    curl -L -o sigma.zip https://github.com/SigmaHQ/sigma/archive/refs/heads/master.zip
    unzip -q sigma.zip
    mv sigma-master "$SIGMA_DIR"
    rm sigma.zip
fi

# ✅ Create output directory
mkdir -p "$OUTPUT_DIR"

# 🔍 Check for EVTX files
shopt -s nullglob
EVTX_FILES=("$EVTX_DIR"/*.evtx)
if [ ${#EVTX_FILES[@]} -eq 0 ]; then
    echo "⚠️  No .evtx files found in: \"$EVTX_DIR\""
    exit 1
else
    echo "📄 Found ${#EVTX_FILES[@]} .evtx file(s) to scan."
fi

# 🚀 Run Chainsaw (v2.11 syntax)
echo ""
echo "🚀 Running Chainsaw hunt..."
chainsaw hunt \
  --sigma "$SIGMA_RULES" \
  --mapping "$MAPPING_FILE" \
  --output "$OUTPUT_DIR" \
  --csv \
  "$EVTX_DIR"

echo ""
echo "✅ Done! Results saved to: \"$OUTPUT_DIR\""
