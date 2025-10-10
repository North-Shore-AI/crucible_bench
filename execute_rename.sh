#!/bin/bash

set -euo pipefail

# Load configuration from parent script
OLD_NAME_LOWER="bench"
OLD_NAME_CAMEL="Bench"
OLD_ATOM=":bench"
NEW_NAME_LOWER="crucible_bench"
NEW_NAME_CAMEL="CrucibleBench"
NEW_ATOM=":crucible_bench"

echo "════════════════════════════════════════════════════════════════"
echo "  EXECUTING LIVE RENAME: ${OLD_NAME_CAMEL} → ${NEW_NAME_CAMEL}"
echo "════════════════════════════════════════════════════════════════"
echo

# 1. Clean build artifacts
echo "[1/15] Cleaning build artifacts and Hex packages..."
rm -rf _build deps *.tar ${OLD_NAME_LOWER}-*/
echo "  ✓ Removed build artifacts"
echo

# 2. Update .gitignore
echo "[2/15] Updating .gitignore..."
grep -q '^\*.tar$' .gitignore 2>/dev/null || echo '*.tar' >> .gitignore
grep -q "^${OLD_NAME_LOWER}-" .gitignore 2>/dev/null || echo "${OLD_NAME_LOWER}-*/" >> .gitignore
grep -q "^${NEW_NAME_LOWER}-" .gitignore 2>/dev/null || echo "${NEW_NAME_LOWER}-*/" >> .gitignore
echo "  ✓ Updated .gitignore"
echo

# 3. Rename directories
echo "[3/15] Renaming directories..."
[ -d "lib/${OLD_NAME_LOWER}" ] && mv "lib/${OLD_NAME_LOWER}" "lib/${NEW_NAME_LOWER}" && echo "  ✓ Renamed lib/${OLD_NAME_LOWER}/ → lib/${NEW_NAME_LOWER}/"
[ -d "test/${OLD_NAME_LOWER}" ] && mv "test/${OLD_NAME_LOWER}" "test/${NEW_NAME_LOWER}" && echo "  ✓ Renamed test/${OLD_NAME_LOWER}/ → test/${NEW_NAME_LOWER}/"
echo

# 4. Update module definitions (with submodules)
echo "[4/15] Updating module definitions (with submodules)..."
find . -type f \( -name '*.ex' -o -name '*.exs' -o -name '*.md' \) ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/defmodule ${OLD_NAME_CAMEL}\./defmodule ${NEW_NAME_CAMEL}./g" {} +
echo "  ✓ Updated submodule definitions"
echo

# 5. Update top-level module definition
echo "[5/15] Updating top-level module definition..."
find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/defmodule ${OLD_NAME_CAMEL} do/defmodule ${NEW_NAME_CAMEL} do/g" {} +
echo "  ✓ Updated top-level module"
echo

# 6. Update alias statements
echo "[6/15] Updating alias statements..."
find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/alias ${OLD_NAME_CAMEL}$/alias ${NEW_NAME_CAMEL}/g" {} +
find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/alias ${OLD_NAME_CAMEL},/alias ${NEW_NAME_CAMEL},/g" {} +
find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/alias ${OLD_NAME_CAMEL}\./alias ${NEW_NAME_CAMEL}./g" {} +
echo "  ✓ Updated alias statements"
echo

# 7. Update module usage
echo "[7/15] Updating module usage..."
find . -type f \( -name '*.ex' -o -name '*.exs' -o -name '*.md' \) ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/${OLD_NAME_CAMEL}\./${NEW_NAME_CAMEL}./g" {} +
echo "  ✓ Updated module usage"
echo

# 8. Update standalone module references in prose/titles
echo "[8/15] Updating prose and titles..."
find . -type f -name '*.md' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/# ${OLD_NAME_CAMEL} -/# ${NEW_NAME_CAMEL} -/g" {} +
find . -type f -name '*.md' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/^${OLD_NAME_CAMEL} provides/${NEW_NAME_CAMEL} provides/g" {} +
find . -type f -name '*.md' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/\. ${OLD_NAME_CAMEL} provides/. ${NEW_NAME_CAMEL} provides/g" {} +
echo "  ✓ Updated prose and titles"
echo

# 9. Update app atom references
echo "[9/15] Updating app atom references..."
find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/${OLD_ATOM}/${NEW_ATOM}/g" {} +
echo "  ✓ Updated ${OLD_ATOM} → ${NEW_ATOM}"
echo

# 10. Update string references
echo "[10/15] Updating string references..."
find . -type f -name 'mix.exs' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/\"${OLD_NAME_LOWER}\"/\"${NEW_NAME_LOWER}\"/g" {} +
find . -type f -name 'README.md' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/{:${OLD_NAME_LOWER},/{:${NEW_NAME_LOWER},/g" {} +
echo "  ✓ Updated string references"
echo

# 11. Update package name field
echo "[11/15] Updating package name field..."
find . -type f -name 'mix.exs' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/name: \"${OLD_NAME_LOWER}\"/name: \"${NEW_NAME_LOWER}\"/g" {} +
echo "  ✓ Updated package name"
echo

# 12. Update app field
echo "[12/15] Updating app field..."
find . -type f -name 'mix.exs' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/app: ${OLD_ATOM}/app: ${NEW_ATOM}/g" {} +
echo "  ✓ Updated app field"
echo

# 13. Update main doc field
echo "[13/15] Updating main doc field..."
find . -type f -name 'mix.exs' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s/main: \"${OLD_NAME_CAMEL}\"/main: \"${NEW_NAME_CAMEL}\"/g" {} +
echo "  ✓ Updated main field"
echo

# 14. Remove umbrella-specific references
echo "[14/15] Removing umbrella-specific references..."
find . -type f -name 'README.md' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "/sparse:.*apps\/${OLD_NAME_LOWER}/d" {} +
find . -type f -name 'README.md' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "/cd apps\/${OLD_NAME_LOWER}/d" {} +
find . -type f -name 'README.md' ! -path './.git/*' ! -path "./${OLD_NAME_LOWER}-*/*" -exec sed -i "s|lib/${OLD_NAME_LOWER}/|lib/${NEW_NAME_LOWER}/|g" {} +
echo "  ✓ Removed umbrella references"
echo

# 15. Verify
echo "[15/15] Verification..."
REMAINING_ATOM=$(grep -r "${OLD_ATOM}[^a-z_]" --include="*.ex" --include="*.exs" . 2>/dev/null | grep -v ".git" | wc -l || echo "0")
REMAINING_MODULE=$(grep -r "defmodule ${OLD_NAME_CAMEL}" --include="*.ex" . 2>/dev/null | grep -v ".git" | wc -l || echo "0")
echo "  Remaining ${OLD_ATOM} references: $REMAINING_ATOM (should be 0)"
echo "  Remaining defmodule ${OLD_NAME_CAMEL} references: $REMAINING_MODULE (should be 0)"
echo

echo "════════════════════════════════════════════════════════════════"
echo "  ✓ RENAME COMPLETE"
echo "════════════════════════════════════════════════════════════════"
echo
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Test compilation: mix deps.get && mix compile"
echo "  3. Run tests: mix test"
echo "  4. Update source_url in mix.exs to point to new GitHub repo"
