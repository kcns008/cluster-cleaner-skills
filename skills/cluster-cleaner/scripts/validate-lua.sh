#!/bin/bash
set -e

usage() {
    cat << EOF
Validate Lua evaluation scripts for k8s-cleaner

Usage: $0 [OPTIONS] LUA_FILE

OPTIONS:
    -h, --help    Show this help

EXAMPLES:
    $0 my-lua-script.lua
    $0 /path/to/evaluation.lua
EOF
    exit 1
}

if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

LUA_FILE="$1"

if [ ! -f "$LUA_FILE" ]; then
    echo "Error: File not found: $LUA_FILE"
    exit 1
fi

echo "Validating Lua script: $LUA_FILE"
echo ""

# Check for basic Lua syntax issues
echo "Checking syntax..."

# Must have evaluate function
if ! grep -q "function evaluate()" "$LUA_FILE"; then
    echo "Warning: No 'function evaluate()' found"
fi

# Must return hs
if ! grep -q "return hs" "$LUA_FILE"; then
    echo "Warning: No 'return hs' found"
fi

# Common patterns
echo ""
echo "Checking common patterns..."

# hs.matching
if grep -q "hs.matching" "$LUA_FILE"; then
    echo "  [OK] hs.matching assignment found"
else
    echo "  [WARN] No hs.matching assignment found"
fi

# hs.message
if grep -q "hs.message" "$LUA_FILE"; then
    echo "  [OK] hs.message found"
else
    echo "  [INFO] No hs.message found (optional)"
fi

# hs.resources (for aggregated selection)
if grep -q "hs.resources" "$LUA_FILE"; then
    echo "  [OK] hs.resources found (aggregated selection)"
fi

# Check for obj usage
if grep -q "obj\." "$LUA_FILE"; then
    echo "  [OK] obj usage found"
fi

# Check for resources array usage (aggregated)
if grep -q "resources\[" "$LUA_FILE"; then
    echo "  [OK] resources array usage found (aggregated selection)"
fi

echo ""
echo "Lua script analysis complete."
echo ""
echo "To test against actual resources, use the k8s-cleaner validate feature:"
echo "  https://github.com/gianlucam76/k8s-cleaner/blob/main/internal/controller/executor/validate_transform/README.md"
