#!/bin/bash
# Hook: Create per-worktree PostgreSQL database
# Copy to: .wt/hooks/post-create and .wt/hooks/pre-delete

# Configuration - customize these
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
DB_PREFIX="${DB_PREFIX:-app_wt}"

DB_NAME="${DB_PREFIX}_${WORKTREE_NAME}"

# ---- POST-CREATE ----
if [[ "${0##*/}" == "post-create" || "${1:-}" == "create" ]]; then
    echo "Creating database '$DB_NAME'..."

    if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
        echo "  ⚠ Postgres container not running, skipping database creation"
        exit 0
    fi

    # Check if database exists
    if docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "  ⚠ Database '$DB_NAME' already exists, reusing"
    else
        docker exec "$POSTGRES_CONTAINER" createdb -U "$POSTGRES_USER" "$DB_NAME" 2>/dev/null && \
            echo "  ✓ Created database '$DB_NAME'" || \
            echo "  ⚠ Failed to create database"
    fi

    # Update DATABASE_URL in .env
    if [[ -f "$WORKTREE_PATH/.env" ]]; then
        if grep -q "^DATABASE_URL=" "$WORKTREE_PATH/.env"; then
            sed -i '' "s|^DATABASE_URL=.*|DATABASE_URL=\"postgresql://${POSTGRES_USER}:${POSTGRES_USER}@localhost:5432/${DB_NAME}\"|" "$WORKTREE_PATH/.env"
        else
            echo "DATABASE_URL=\"postgresql://${POSTGRES_USER}:${POSTGRES_USER}@localhost:5432/${DB_NAME}\"" >> "$WORKTREE_PATH/.env"
        fi
        echo "  ✓ Updated DATABASE_URL in .env"
    fi

    # Run migrations if Prisma is available
    if [[ -f "$WORKTREE_PATH/prisma/schema.prisma" ]]; then
        echo "Running database migrations..."
        (cd "$WORKTREE_PATH" && npx prisma migrate deploy 2>/dev/null) && \
            echo "  ✓ Migrations applied" || \
            echo "  ⚠ Migration failed (may need to run manually)"
    fi
fi

# ---- PRE-DELETE ----
if [[ "${0##*/}" == "pre-delete" || "${1:-}" == "delete" ]]; then
    echo "Dropping database '$DB_NAME'..."

    if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
        echo "  ⚠ Postgres container not running, skipping"
        exit 0
    fi

    if docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        docker exec "$POSTGRES_CONTAINER" dropdb -U "$POSTGRES_USER" "$DB_NAME" 2>/dev/null && \
            echo "  ✓ Dropped database '$DB_NAME'" || \
            echo "  ⚠ Failed to drop database"
    fi
fi
