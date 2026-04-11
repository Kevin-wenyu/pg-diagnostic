#!/usr/bin/env bash
# Release script for pg-diagnostic

set -e

VERSION="$1"

if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh <version>"
    echo "Example: ./release.sh 4.3.0"
    exit 1
fi

# Validate version format (semver)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format X.Y.Z"
    exit 1
fi

echo "Preparing release v$VERSION..."

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: You have uncommitted changes. Please commit or stash them first."
    exit 1
fi

# Update version in pg script
echo "Updating version in pg script..."
sed -i "s/^VERSION=.*/VERSION=\"$VERSION\"/" pg
sed -i "s/^Build:.*/Build: $(date +%Y-%m-%d)/" pg

# Update CHANGELOG.md
echo "Updating CHANGELOG.md..."
CHANGELOG_DATE=$(date +%Y-%m-%d)
sed -i "s/## \[Unreleased\]/## [$VERSION] - $CHANGELOG_DATE/" CHANGELOG.md
sed -i "s/## \[Unreleased\]/## [Unreleased]/" CHANGELOG.md

# Commit changes
echo "Committing changes..."
git add pg CHANGELOG.md
git commit -m "release: bump version to $VERSION"

# Create tag
echo "Creating tag v$VERSION..."
git tag -a "v$VERSION" -m "Release v$VERSION"

echo ""
echo "Release v$VERSION prepared!"
echo ""
echo "To push and release:"
echo "  git push && git push origin v$VERSION"
echo ""
echo "To cancel:"
echo "  git reset --hard HEAD~1 && git tag -d v$VERSION"