#!/bin/bash

# Exit on error
set -e

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Error: Not in a git repository"
  exit 1
fi

# Get a list of modified files
modified_files=$(git status --porcelain | grep -E '^ ?M|^[AM]' | awk '{print $2}')

if [ -z "$modified_files" ]; then
  echo "No modified files found."
  exit 0
fi

echo "Found the following modified files:"
echo "$modified_files"
echo "Removing trailing whitespace..."

# Process each modified file
echo "$modified_files" | while read -r file; do
  # Skip if file doesn't exist or isn't a regular file
  if [ ! -f "$file" ]; then
    echo "Skipping $file (not a regular file)"
    continue
  fi
  
  # Create a backup just in case
  cp "$file" "$file.bak"
  
  # Remove trailing whitespace and blank lines at EOF
  # sed options:
  # -i: edit files in place
  # -e: specify a script
  sed -i -e 's/[[:space:]]*$//' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$file"
  
  echo "Cleaned: $file"
done

echo "All files processed. Backups created as *.bak"
echo "You can review changes and then run 'find . -name \"*.bak\" -delete' to remove backups"
