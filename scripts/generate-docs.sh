#!/usr/bin/env bash
# Generates a single README.md for the platform-orchestrator chart with a
# unified values table that includes all subchart values (prefixed with their
# alias / dependency name).
set -euo pipefail

HELM_DOCS="${HELM_DOCS:-helm-docs}"
CHART_DIR="charts/platform-orchestrator"
PARENT_README="$CHART_DIR/README.md"
TMPDIR_DOCS=$(mktemp -d)
trap 'rm -rf "$TMPDIR_DOCS"' EXIT

# ---------------------------------------------------------------------------
# 1. Generate the parent README (values table from parent values.yaml only,
#    plus HTML markers where subchart rows will be injected).
# ---------------------------------------------------------------------------
"$HELM_DOCS" --chart-search-root "$CHART_DIR" --template-files README.md.gotmpl

# ---------------------------------------------------------------------------
# 2. Generate subchart READMEs (each has its own clean values table).
# ---------------------------------------------------------------------------
"$HELM_DOCS" --chart-search-root "$CHART_DIR/charts" --template-files README.md.gotmpl

# ---------------------------------------------------------------------------
# 3. Collect keys already present in the parent values table.
# ---------------------------------------------------------------------------
# Extract data rows from the parent README values section.
# Values section starts with "| Key |" and ends at the next "##" or marker.
sed -n '/^| Key | Type /,/^$/p' "$PARENT_README" \
  | grep '^| ' \
  | grep -v '^| Key ' \
  | grep -v '^|---' \
  > "$TMPDIR_DOCS/parent-rows.txt" || true

# Extract just the key column for dedup lookups
awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}' "$TMPDIR_DOCS/parent-rows.txt" \
  | sed 's/ *$//' \
  > "$TMPDIR_DOCS/parent-keys.txt"

# ---------------------------------------------------------------------------
# 4. Extract subchart value rows, prefix keys, skip duplicates.
# ---------------------------------------------------------------------------

# extract_rows <subchart-readme> <prefix> >> output
extract_rows() {
  local readme="$1" prefix="$2"
  # Get data rows from the subchart README values table
  sed -n '/^| Key | Type /,/^$/p' "$readme" \
    | grep '^| ' \
    | grep -v '^| Key ' \
    | grep -v '^|---' \
    | sed "s/^| /| ${prefix}./"
}

EXTRA_ROWS="$TMPDIR_DOCS/extra-rows.txt"
: > "$EXTRA_ROWS"

# add_subchart <dir> <prefix>
add_subchart() {
  local dir="$1" prefix="$2"
  local readme="$CHART_DIR/charts/$dir/README.md"
  [ -f "$readme" ] || { echo "Warning: $readme not found" >&2; return; }

  extract_rows "$readme" "$prefix" > "$TMPDIR_DOCS/${prefix}-rows.txt"

  while IFS= read -r line; do
    key=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}')
    if ! grep -qxF "$key" "$TMPDIR_DOCS/parent-keys.txt"; then
      echo "$line" >> "$EXTRA_ROWS"
    fi
  done < "$TMPDIR_DOCS/${prefix}-rows.txt"
}

# backend-module is aliased three times
add_subchart "backend-module" "control-plane"
add_subchart "backend-module" "data-plane"
add_subchart "backend-module" "iam"

# Other subcharts
add_subchart "console"        "console"
add_subchart "cnpg-databases" "cnpg-databases"
add_subchart "keycloak"       "keycloak"

# ---------------------------------------------------------------------------
# 5. Merge: combine parent rows + extra rows, sort, rebuild table.
# ---------------------------------------------------------------------------
cat "$TMPDIR_DOCS/parent-rows.txt" "$EXTRA_ROWS" \
  | sort -t'|' -k2,2 \
  > "$TMPDIR_DOCS/all-sorted.txt"

{
  echo "## Values"
  echo ""
  echo "| Key | Type | Default | Description |"
  echo "|-----|------|---------|-------------|"
  cat "$TMPDIR_DOCS/all-sorted.txt"
} > "$TMPDIR_DOCS/values-block.md"

# ---------------------------------------------------------------------------
# 6. Replace the original values section + subchart markers with the merged table.
#    We replace from "## Values" up to (but not including) "## Required Secrets".
# ---------------------------------------------------------------------------
perl -0777 -i -pe '
  open(my $fh, "<", "'"$TMPDIR_DOCS/values-block.md"'") or die "Cannot read values block: $!";
  my $block = do { local $/; <$fh> };
  close $fh;
  chomp $block;
  s/## Values\n.*?<!-- SUBCHART_VALUES_END -->/$block/s;
' "$PARENT_README"

echo "Documentation generated: $PARENT_README"
