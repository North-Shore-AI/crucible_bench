#!/bin/bash

set -euo pipefail

################################################################################
# CONFIGURATION - Edit these for each repo
################################################################################
OLD_NAME_LOWER="bench"                    # lowercase: bench, ensemble, hedging, etc.
OLD_NAME_CAMEL="Bench"                    # CamelCase: Bench, Ensemble, Hedging, etc.
OLD_ATOM=":bench"                         # atom: :bench, :ensemble, :hedging, etc.

NEW_NAME_LOWER="crucible_bench"           # new lowercase name
NEW_NAME_CAMEL="CrucibleBench"            # new CamelCase name
NEW_ATOM=":crucible_bench"                # new atom name
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Crucible Renaming Script - DRY RUN${NC}"
echo -e "${BLUE}  ${OLD_NAME_CAMEL} → ${NEW_NAME_CAMEL}${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo

# Step 1: Clean build artifacts and add to gitignore
echo -e "${YELLOW}[Step 1] Cleaning build artifacts and updating .gitignore...${NC}"
echo "  Will remove: _build/ deps/ *.tar ${OLD_NAME_LOWER}-*/"
if [ -d "_build" ] || [ -d "deps" ]; then
    echo -e "${GREEN}  Found build directories${NC}"
fi
if ls *.tar 1> /dev/null 2>&1; then
    echo -e "${GREEN}  Found Hex package tarball(s): $(ls *.tar)${NC}"
fi
if ls -d ${OLD_NAME_LOWER}-[0-9]* 2>/dev/null; then
    echo -e "${GREEN}  Found Hex package directory(s)${NC}"
fi

echo
echo "  Will add to .gitignore:"
echo "    *.tar"
echo "    ${OLD_NAME_LOWER}-*/"
echo "    ${NEW_NAME_LOWER}-*/"
echo

# Step 1b: Directory renames
echo -e "${YELLOW}[Step 1b] Checking for directory renames...${NC}"
if [ -d "lib/${OLD_NAME_LOWER}" ]; then
    echo -e "${GREEN}  Will rename: lib/${OLD_NAME_LOWER}/ → lib/${NEW_NAME_LOWER}/${NC}"
fi
if [ -d "test/${OLD_NAME_LOWER}" ]; then
    echo -e "${GREEN}  Will rename: test/${OLD_NAME_LOWER}/ → test/${NEW_NAME_LOWER}/${NC}"
fi
echo

# Step 2: Find all files that will be affected
echo -e "${YELLOW}[Step 2] Searching for files with '${OLD_NAME_LOWER}', '${OLD_NAME_CAMEL}', or '${OLD_ATOM}'...${NC}"
echo

# Search patterns
echo -e "${BLUE}Files containing module name '${OLD_NAME_CAMEL}':${NC}"
MODULE_MATCHES=$(grep -r "${OLD_NAME_CAMEL}" --include="*.ex" --include="*.exs" --include="*.md" . 2>/dev/null | grep -v ".git" | grep -v "${OLD_NAME_LOWER}-[0-9]" | wc -l)
echo "  Found $MODULE_MATCHES matches"
echo

echo -e "${BLUE}Files containing app atom '${OLD_ATOM}':${NC}"
ATOM_MATCHES=$(grep -r "${OLD_ATOM}" --include="*.ex" --include="*.exs" --include="*.md" . 2>/dev/null | grep -v ".git" | grep -v "${OLD_NAME_LOWER}-[0-9]" | wc -l)
echo "  Found $ATOM_MATCHES matches"
echo

echo -e "${BLUE}Files containing package name '${OLD_NAME_LOWER}':${NC}"
PKG_MATCHES=$(grep -r "\"${OLD_NAME_LOWER}\"" --include="*.exs" --include="*.md" . 2>/dev/null | grep -v ".git" | grep -v "${OLD_NAME_LOWER}-[0-9]" | wc -l)
echo "  Found $PKG_MATCHES matches"
echo

# Step 3: Show proposed replacements in diff format
echo -e "${YELLOW}[Step 3] Proposed replacements (showing samples):${NC}"
echo

# Simulate actual transformations
echo -e "${BLUE}Sample transformations:${NC}"
echo
echo -e "${GREEN}1. Module definition (with submodule):${NC}"
echo "   BEFORE: defmodule ${OLD_NAME_CAMEL}.Stats do"
echo "   AFTER:  defmodule ${NEW_NAME_CAMEL}.Stats do"
echo

echo -e "${GREEN}2. Module definition (top-level):${NC}"
echo "   BEFORE: defmodule ${OLD_NAME_CAMEL} do"
echo "   AFTER:  defmodule ${NEW_NAME_CAMEL} do"
echo

echo -e "${GREEN}3. Alias statement:${NC}"
echo "   BEFORE: alias ${OLD_NAME_CAMEL}.Stats"
echo "   AFTER:  alias ${NEW_NAME_CAMEL}.Stats"
echo

echo -e "${GREEN}4. Module usage:${NC}"
echo "   BEFORE: result = ${OLD_NAME_CAMEL}.compare(a, b)"
echo "   AFTER:  result = ${NEW_NAME_CAMEL}.compare(a, b)"
echo

echo -e "${GREEN}5. App atom:${NC}"
echo "   BEFORE: app: ${OLD_ATOM},"
echo "   AFTER:  app: ${NEW_ATOM},"
echo

echo -e "${GREEN}6. Dependency:${NC}"
echo "   BEFORE: {${OLD_ATOM}, \"~> 0.1.0\"}"
echo "   AFTER:  {${NEW_ATOM}, \"~> 0.1.0\"}"
echo

echo -e "${GREEN}7. README title:${NC}"
echo "   BEFORE: # ${OLD_NAME_CAMEL} - Statistical Testing"
echo "   AFTER:  # ${NEW_NAME_CAMEL} - Statistical Testing"
echo

echo -e "${GREEN}8. Prose (at start of sentence):${NC}"
echo "   BEFORE: ${OLD_NAME_CAMEL} provides rigorous tests"
echo "   AFTER:  ${NEW_NAME_CAMEL} provides rigorous tests"
echo

echo -e "${GREEN}9. Directory reference:${NC}"
echo "   BEFORE: cd apps/${OLD_NAME_LOWER}"
echo "   AFTER:  (will be manually removed - not applicable post-umbrella)"
echo

echo -e "${GREEN}10. Sparse path reference:${NC}"
echo "   BEFORE: sparse: \"apps/${OLD_NAME_LOWER}\""
echo "   AFTER:  (will be manually removed - not applicable post-umbrella)"
echo

# Step 4: Show counts
echo -e "${YELLOW}[Step 4] Statistics:${NC}"
echo
MODULE_DEF_COUNT=$(grep -r "defmodule ${OLD_NAME_CAMEL}" --include="*.ex" --include="*.exs" . 2>/dev/null | grep -v ".git" | grep -v "${OLD_NAME_LOWER}-[0-9]" | wc -l || echo "0")
ALIAS_COUNT=$(grep -r "alias ${OLD_NAME_CAMEL}" --include="*.ex" --include="*.exs" . 2>/dev/null | grep -v ".git" | grep -v "${OLD_NAME_LOWER}-[0-9]" | wc -l || echo "0")
ATOM_COUNT=$(grep -r "${OLD_ATOM}" --include="*.ex" --include="*.exs" . 2>/dev/null | grep -v ".git" | grep -v "${OLD_NAME_LOWER}-[0-9]" | wc -l || echo "0")
STRING_COUNT=$(grep -r "\"${OLD_NAME_LOWER}\"" --include="*.exs" --include="*.md" . 2>/dev/null | grep -v ".git" | grep -v "${OLD_NAME_LOWER}-[0-9]" | wc -l || echo "0")

echo "  Module definitions (defmodule ${OLD_NAME_CAMEL}):    $MODULE_DEF_COUNT"
echo "  Alias statements (alias ${OLD_NAME_CAMEL}):          $ALIAS_COUNT"
echo "  Atom references (${OLD_ATOM}):                       $ATOM_COUNT"
echo "  String references (\"${OLD_NAME_LOWER}\"):             $STRING_COUNT"
echo

# Step 5: Show the LIVE commands that would be executed
echo -e "${YELLOW}[Step 5] LIVE COMMANDS (to run after verification):${NC}"
echo
echo -e "${BLUE}# 1. Clean build artifacts and Hex packages${NC}"
echo "rm -rf _build deps *.tar ${OLD_NAME_LOWER}-*/"
echo
echo -e "${BLUE}# 2. Update .gitignore${NC}"
echo "grep -q '^\*.tar$' .gitignore 2>/dev/null || echo '*.tar' >> .gitignore"
echo "grep -q '^${OLD_NAME_LOWER}-' .gitignore 2>/dev/null || echo '${OLD_NAME_LOWER}-*/' >> .gitignore"
echo "grep -q '^${NEW_NAME_LOWER}-' .gitignore 2>/dev/null || echo '${NEW_NAME_LOWER}-*/' >> .gitignore"
echo
echo -e "${BLUE}# 3. Rename directories${NC}"
echo "[ -d lib/${OLD_NAME_LOWER} ] && mv lib/${OLD_NAME_LOWER} lib/${NEW_NAME_LOWER}"
echo "[ -d test/${OLD_NAME_LOWER} ] && mv test/${OLD_NAME_LOWER} test/${NEW_NAME_LOWER}"
echo
echo -e "${BLUE}# 4. Update module definitions (with submodules)${NC}"
echo "find . -type f \( -name '*.ex' -o -name '*.exs' -o -name '*.md' \) ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/defmodule ${OLD_NAME_CAMEL}\./defmodule ${NEW_NAME_CAMEL}./g' {} +"
echo
echo -e "${BLUE}# 5. Update top-level module definition${NC}"
echo "find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/defmodule ${OLD_NAME_CAMEL} do/defmodule ${NEW_NAME_CAMEL} do/g' {} +"
echo
echo -e "${BLUE}# 6. Update alias statements${NC}"
echo "find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/alias ${OLD_NAME_CAMEL}$/alias ${NEW_NAME_CAMEL}/g' {} +"
echo "find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/alias ${OLD_NAME_CAMEL},/alias ${NEW_NAME_CAMEL},/g' {} +"
echo "find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/alias ${OLD_NAME_CAMEL}\./alias ${NEW_NAME_CAMEL}./g' {} +"
echo
echo -e "${BLUE}# 7. Update module usage${NC}"
echo "find . -type f \( -name '*.ex' -o -name '*.exs' -o -name '*.md' \) ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/${OLD_NAME_CAMEL}\./${NEW_NAME_CAMEL}./g' {} +"
echo
echo -e "${BLUE}# 8. Update standalone module references in prose/titles${NC}"
echo "find . -type f -name '*.md' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/# ${OLD_NAME_CAMEL} -/# ${NEW_NAME_CAMEL} -/g' {} +"
echo "find . -type f -name '*.md' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/^${OLD_NAME_CAMEL} provides/${NEW_NAME_CAMEL} provides/g' {} +"
echo "find . -type f -name '*.md' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/\. ${OLD_NAME_CAMEL} provides/. ${NEW_NAME_CAMEL} provides/g' {} +"
echo
echo -e "${BLUE}# 9. Update app atom references${NC}"
echo "find . -type f \( -name '*.ex' -o -name '*.exs' \) ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/${OLD_ATOM}/${NEW_ATOM}/g' {} +"
echo
echo -e "${BLUE}# 10. Update string references in mix.exs and README${NC}"
echo "find . -type f -name 'mix.exs' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/\"${OLD_NAME_LOWER}\"/\"${NEW_NAME_LOWER}\"/g' {} +"
echo "find . -type f -name 'README.md' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/{:${OLD_NAME_LOWER},/{:${NEW_NAME_LOWER},/g' {} +"
echo
echo -e "${BLUE}# 11. Update package name field${NC}"
echo "find . -type f -name 'mix.exs' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/name: \"${OLD_NAME_LOWER}\"/name: \"${NEW_NAME_LOWER}\"/g' {} +"
echo
echo -e "${BLUE}# 12. Update app field${NC}"
echo "find . -type f -name 'mix.exs' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/app: ${OLD_ATOM}/app: ${NEW_ATOM}/g' {} +"
echo
echo -e "${BLUE}# 13. Update main doc field${NC}"
echo "find . -type f -name 'mix.exs' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's/main: \"${OLD_NAME_CAMEL}\"/main: \"${NEW_NAME_CAMEL}\"/g' {} +"
echo
echo -e "${BLUE}# 14. Remove umbrella-specific references${NC}"
echo "find . -type f -name 'README.md' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i '/sparse:.*apps\\/${OLD_NAME_LOWER}/d' {} +"
echo "find . -type f -name 'README.md' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i '/cd apps\\/${OLD_NAME_LOWER}/d' {} +"
echo "find . -type f -name 'README.md' ! -path './.git/*' ! -path './${OLD_NAME_LOWER}-*/*' -exec sed -i 's|lib/${OLD_NAME_LOWER}/|lib/${NEW_NAME_LOWER}/|g' {} +"
echo

# Step 6: Create the actual execution script
echo -e "${YELLOW}[Step 6] Creating execute script...${NC}"
cat > execute_rename.sh << 'EOFSCRIPT'
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
EOFSCRIPT

chmod +x execute_rename.sh
echo -e "${GREEN}Created: execute_rename.sh${NC}"
echo

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  DRY RUN COMPLETE${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo
echo -e "${YELLOW}To execute the rename, run:${NC}"
echo -e "${GREEN}  ./execute_rename.sh${NC}"
echo
echo -e "${YELLOW}Manual steps after running:${NC}"
echo "  1. Update source_url in mix.exs to: https://github.com/North-Shore-AI/${NEW_NAME_LOWER}"
echo "  2. Review git diff carefully"
echo "  3. Test: mix deps.get && mix compile && mix test"
echo
