#!/bin/bash
# Hook: Hard-link node_modules from main project
# Copy to: .wt/hooks/post-create

# Hard-link node_modules for instant setup (same files, no disk space)
if [[ -d "$WT_PROJECT_ROOT/node_modules" ]]; then
    echo "Linking node_modules..."
    if cp -Rl "$WT_PROJECT_ROOT/node_modules" "$WORKTREE_PATH/node_modules" 2>/dev/null; then
        echo "  ✓ Linked node_modules (hard links)"
    else
        # Fallback to npm/yarn install if hard links fail
        echo "  Hard links failed, running install..."
        if [[ -f "$WORKTREE_PATH/yarn.lock" ]]; then
            (cd "$WORKTREE_PATH" && yarn install --frozen-lockfile --prefer-offline --silent)
        elif [[ -f "$WORKTREE_PATH/pnpm-lock.yaml" ]]; then
            (cd "$WORKTREE_PATH" && pnpm install --frozen-lockfile)
        else
            (cd "$WORKTREE_PATH" && npm ci --prefer-offline --silent)
        fi
        echo "  ✓ Installed dependencies"
    fi
fi
