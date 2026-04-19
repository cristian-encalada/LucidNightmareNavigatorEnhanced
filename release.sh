#!/bin/bash
set -e

ADDON="LucidNav"
TOC="${ADDON}.toc"

VERSION=$(grep -i '^## Version:' "$TOC" | awk -F': ' '{print $2}' | tr -d '\r')

if [ -z "$VERSION" ]; then
  echo "Error: Version not found in $TOC"
  exit 1
fi

mkdir -p release

ZIP="release/${ADDON}-${VERSION}.zip"

echo "Packaging ${ADDON} version ${VERSION}..."

git archive \
  --format=zip \
  --prefix="${ADDON}/" \
  --output="$ZIP" \
  HEAD

echo "Created $ZIP"
echo "Size: $(du -h "$ZIP" | cut -f1)"
