#!/bin/sh
# Creates a separate database inside your existing postgres container.
#
# Usage:
#   sh scripts/setup-db.sh <container-name-or-id> <postgres-superuser>
#
# Example:
#   sh scripts/setup-db.sh my-postgres-container postgres
#
set -e

CONTAINER=${1:?Usage: $0 <postgres-container> <superuser>}
PGUSER=${2:?Usage: $0 <postgres-container> <superuser>}

docker exec -i "$CONTAINER" psql -U "$PGUSER" <<SQL
CREATE USER summitsplit WITH PASSWORD 'changeme';
CREATE DATABASE summitsplit OWNER summitsplit;
SQL

echo "Done. Test connection with:"
echo "  docker exec -it $CONTAINER psql -U summitsplit -d summitsplit"
