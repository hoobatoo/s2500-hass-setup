#!/bin/bash

# aruba_poe_wrapper.sh - Wrapper to ensure expect is installed before calling the expect script
# Version: 1.2.0
# Usage: aruba_poe_wrapper.sh <port_number> <enable|disable|status>
#
# Version History:
# v1.2.0 (2025-03-03) - Remove debug mode
#   - Removed -D flag and debug functionality
#   - Version sync with expect script v1.2.0
#   - Streamlined code for cleaner operation
# v1.1.0 (2025-03-03) - Complete rewrite of status handling
#   - Version sync with expect script v1.1.0
#   - Simplified file-based approach
#   - Improved file permissions and error handling
# v1.0.9 (2025-03-03) - Fix file reading in expect script
#   - Version sync with expect script v1.0.9
#   - Improved reliability for status output
# v1.0.8 (2025-03-03) - Update to match expect script file-based output
#   - Version sync with expect script v1.0.8
#   - Compatible with file-based status handling in expect script
# v1.0.7 (2025-03-03) - Simple direct approach
#   - Simplified output processing 
#   - Direct output forwarding
# v1.0.6 (2025-03-03) - Fix switch prompt output issue
#   - Added grep filter for status output
#   - Better handling of special marker for status lines
# v1.0.5 (2025-03-03) - Targeted status line handling
#   - Pass through status line without additional processing
# v1.0.4 (2025-03-03) - Fix status command output formatting
#   - Simplified output processing for status command
# v1.0.3 (2025-03-03) - Add debug mode
#   - Added -D flag for debug output
#   - Simplified output processing
# v1.0.2 (2025-03-03) - Fix status command output
#   - Better handling of tagged output from expect script
#   - More reliable output extraction
# v1.0.1 (2025-03-03) - Better output control
#   - Capture and filter script output
# v1.0.0 (2025-03-03) - Initial versioned release
#   - Added version information
#   - Better error handling

# Script version
SCRIPT_VERSION="1.2.0"

# Check if required arguments are provided
if [ $# -lt 2 ]; then
  echo "aruba_poe_wrapper.sh v$SCRIPT_VERSION - Usage: $0 <port_number> <enable|disable|status>" >&2
  exit 1
fi

PORT=$1
ACTION=$2

# Define the path to the expect script
EXPECT_SCRIPT="/config/scripts/aruba_poe.exp"

# Check if the expect script exists
if [ ! -f "$EXPECT_SCRIPT" ]; then
  echo "Error (v$SCRIPT_VERSION): Expect script not found at $EXPECT_SCRIPT" >&2
  exit 1
fi

# Check if expect is installed
if ! command -v expect &> /dev/null; then
  echo "Expect not found. Installing... (wrapper v$SCRIPT_VERSION)" >&2
  apk add --no-cache expect
  
  # Check if installation was successful
  if [ $? -ne 0 ]; then
    echo "Error (v$SCRIPT_VERSION): Failed to install expect. Please install it manually." >&2
    exit 1
  fi
  
  echo "Expect installed successfully. (wrapper v$SCRIPT_VERSION)" >&2
fi

# Make sure the expect script is executable
chmod +x "$EXPECT_SCRIPT"

# Execute the expect script and capture the output
OUTPUT=$("$EXPECT_SCRIPT" "$PORT" "$ACTION")
EXIT_CODE=$?

# Check if the command succeeded
if [ $EXIT_CODE -eq 0 ]; then
  # Success - just echo the output
  echo "$OUTPUT"
  exit 0
else
  # Error - echo the error message
  echo "$OUTPUT"
  exit 1
fi