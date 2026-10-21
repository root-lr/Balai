#!/usr/bin/env bash
# Génère Resources/AppIcon.icns (+ AppIcon.png) à partir du logo dessiné dans l'app.
# Usage : ./scripts/make-icon.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swiftc -parse-as-library -O \
    "$ROOT/scripts/make-icon.swift" \
    "$ROOT/Sources/Balai/Views/BrandIcon.swift" \
    -o "$TMP/make-icon"
"$TMP/make-icon" "$ROOT/Resources"
