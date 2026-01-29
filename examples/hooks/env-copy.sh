#!/bin/bash
# Hook: Copy environment files
# Copy to: .wt/hooks/post-create

# Copy .env from main project
if [[ -f "$WT_PROJECT_ROOT/.env" ]]; then
    cp "$WT_PROJECT_ROOT/.env" "$WORKTREE_PATH/.env"
    echo "  ✓ Copied .env"
fi

# Create .env.local with port overrides
cat > "$WORKTREE_PATH/.env.local" << EOF
PORT=$WORKTREE_PORT
NEXT_PUBLIC_APP_URL=http://localhost:$WORKTREE_PORT
NEXT_PUBLIC_API_URL=http://localhost:$WORKTREE_PORT/api
NEXTAUTH_URL=http://localhost:$WORKTREE_PORT
EOF
echo "  ✓ Created .env.local with PORT=$WORKTREE_PORT"
