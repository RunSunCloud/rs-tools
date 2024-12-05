#!/bin/bash

# Variables
REPO="RunSunCloud/rs-tools"  # Change this to the desired GitHub repository
CURRENT_VERSION="$(cat VERSION)"  # Capture current version
API_URL="https://api.github.com/repos/$REPO/releases/latest"
DOWNLOAD_URL="https://github.com/$REPO/archive/refs/tags"

# Check for latest version on GitHub
LATEST_VERSION=$(curl -s $API_URL | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')

# Compare versions and upgrade if necessary
if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
    echo "Upgrading from version $CURRENT_VERSION to $LATEST_VERSION..."

    # Download the latest version
    curl -L -o /tmp/ "$ASSET_URL"
    wget $DOWNLOAD_URL/${LATEST_VERSION}.tar.gz -P /tmp/


    # Move the new binary to replace the old one
    tar -xzvf /tmp/${LATEST_VERSION}.tar.gz -C ./ --strip-components 1

    echo "Upgrade complete to version $LATEST_VERSION."
else
    echo "You are already on the latest version: $CURRENT_VERSION."
fi
