#!/bin/bash

# Get the Git SHA
GIT_SHA=$(git rev-parse --short HEAD)

# Path to the Info.plist file
# Xcode build environment variables like ${SRCROOT} or ${PROJECT_DIR} are usually available.
# We'll assume the script runs from the project root, so the path is relative.
INFOPLIST_FILE="${SRCROOT}/${INFOPLIST_PATH}" # INFOPLIST_PATH is usually like "YourApp/Info.plist"

# Check if running in Xcode build environment, otherwise try a relative path
if [ -z "$INFOPLIST_FILE" ] || [ ! -f "$INFOPLIST_FILE" ]; then
  # Fallback for when not running in Xcode or if INFOPLIST_PATH isn't set as expected
  # This assumes the script is in the project root and Info.plist is in a standard location
  INFOPLIST_FILE_CANDIDATE_1="AirPods Sound Quality Fixer/Info.plist" # Adjust if your .app name is different
  INFOPLIST_FILE_CANDIDATE_2="${PRODUCT_NAME}/Info.plist" # PRODUCT_NAME is another Xcode var

  if [ -f "$INFOPLIST_FILE_CANDIDATE_1" ]; then
    INFOPLIST_FILE="$INFOPLIST_FILE_CANDIDATE_1"
  elif [ -f "$INFOPLIST_FILE_CANDIDATE_2" ]; then
    INFOPLIST_FILE="$INFOPLIST_FILE_CANDIDATE_2"
  else
    echo "error: Info.plist not found. Tried default Xcode paths and candidates."
    echo "SRCROOT: $SRCROOT, INFOPLIST_PATH: $INFOPLIST_PATH, PRODUCT_NAME: $PRODUCT_NAME"
    exit 1
  fi
fi

echo "Updating Info.plist at $INFOPLIST_FILE with SHA: $GIT_SHA"

# Update the CFBundleVersion with the Git SHA
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $GIT_SHA" "$INFOPLIST_FILE"

# Check if PlistBuddy was successful
if [ $? -ne 0 ]; then
  echo "error: PlistBuddy failed to update Info.plist"
  exit 1
fi

echo "Info.plist CFBundleVersion updated to $GIT_SHA"
exit 0