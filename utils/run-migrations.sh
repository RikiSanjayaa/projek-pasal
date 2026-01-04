#!/bin/bash

# Run all Supabase migrations in order
# Usage: ./utils/run-migrations.sh

set -e

MIGRATIONS_DIR="supabase/migrations"
DB_CONTAINER="supabase-db"
DB_USER="supabase_admin"
DB_NAME="postgres"

echo "Running Supabase migrations..."

# Run each migration file in order
for file in $(ls -v $MIGRATIONS_DIR/*.sql 2>/dev/null); do
    filename=$(basename "$file")
    echo "Running: $filename"
    docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < "$file"
    echo "Completed: $filename"
done

echo ""
echo "All migrations completed successfully!"

# Optional: Run seed data
read -p "Run seed.sql? (y/n): " run_seed
if [ "$run_seed" = "y" ]; then
    echo "Running seed.sql..."
    docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < supabase/seed.sql
    echo "Seed data inserted!"
fi
