#!/bin/bash
# KB Session Check Hook
# Runs on Stop event to remind about KB write-back
#
# This hook checks if the session involved KB-worthy work and
# outputs a reminder in the hook response.

set -e

INPUT=$(cat)

# Extract session info (if available)
# The Stop event doesn't provide much context, but we can use
# environment variables or check recent file changes

# Check if we're in a repo with knowledge-db
if [[ -d "knowledge-db" ]] || [[ -d "../knowledge-db" ]]; then
    KB_PRESENT=true
else
    KB_PRESENT=false
fi

# Output success with optional message
# The message will be shown to the agent as additional context
if [[ "$KB_PRESENT" == true ]]; then
    jq -n '{
        "hookSpecificOutput": {
            "hookEventName": "Stop",
            "additionalContext": "KB_WRITE_BACK_CHECK: If this session involved non-trivial work (debugging, multi-file changes, decisions), ensure a KB entry was created or updated."
        }
    }'
else
    jq -n '{
        "hookSpecificOutput": {
            "hookEventName": "Stop"
        }
    }'
fi

exit 0
