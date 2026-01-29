#!/bin/bash
# Hook: Set up Claude Code status tracking
# Copy to: .wt/hooks/post-create
#
# This creates Claude hooks that write status to /tmp/wt-status-<project>-<name>
# The control center reads these files to show processing/idle status

mkdir -p "$WORKTREE_PATH/.claude"
cat > "$WORKTREE_PATH/.claude/settings.local.json" << EOF
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'processing' > /tmp/wt-status-${WT_PROJECT_NAME}-\$(basename \"\$PWD\")"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'idle' > /tmp/wt-status-${WT_PROJECT_NAME}-\$(basename \"\$PWD\")"
          }
        ]
      }
    ]
  }
}
EOF
echo "  ✓ Set up Claude status hooks"
