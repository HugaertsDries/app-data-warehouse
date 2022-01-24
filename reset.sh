#!/bin/bash
# NOTE: Before usage, make sure executable permission are set `chmod +x to-env.sh`

# Help
usage() { echo "Usage: $0 [-s(kip-intro)] [-d(etatch)] [-h(elp)]" 1>&2; exit 1; }

# File count in folder
count() { return "$(find "$1" -type f | wc -l)"; }

# Variables
SKIP=false
DETATCH=false

DATABASE_BUFFER_DEFAULT=3
DATABASE_BUFFER_HEAVY=60

MIGRATION_BUFFER_DEFAULT=10
MIGRATION_BUFFER_HEAVY=60

# Getting FLAG variables
while getopts "sdh:" flag; do
case ${flag} in
  s) SKIP=true;;
  d) DETATCH=true;;
  h) usage;;
  *) usage;;
esac
done

# START~
if [ "$SKIP" == false ]; then
  echo "[WARNING] This script will completely restart and reset your stack, you have 5 seconds to press CTRL+z"
  sleep 5
fi

sudo docker-compose down --remove-orphans
sudo chmod -R 777 data
sudo rm -Rf data
git checkout data

# Setup database
docker-compose up -d database
# NOTE: take into account .gitkeep
if count ./data/db/toLoad -gt 1; then
  echo "Found data to be loaded into the database ..."
  echo "Giving buffer of ${DATABASE_BUFFER_HEAVY} seconds to complete"
  sleep $DATABASE_BUFFER_HEAVY
else
  echo "Giving database a buffer of ${DATABASE_BUFFER_DEFAULT} seconds to complete"
  sleep $DATABASE_BUFFER_DEFAULT
fi

# Setup migrations
# NOTE: take into account .gitkeep
MIGRATION_COUNT=$(count ./config/migrations)
if [[ "$MIGRATION_COUNT" -gt 1 ]]; then
  echo "Found $MIGRATION_COUNT migration(s) to be processed ..."
  docker-compose up -d migrations
  if $MIGRATION_COUNT -gt 24; then
    echo "Giving migrations a buffer of ${MIGRATION_BUFFER_HEAVY} seconds to complete"
    sleep MIGRATION_BUFFER_HEAVY
  else
     echo "Giving migrations a buffer of ${MIGRATION_BUFFER_DEFAULT} seconds to complete"
     sleep MIGRATION_BUFFER_DEFAULT
  fi
fi

docker-compose up -d
echo "giving stack a buffer of 5 seconds to complete"
sleep 5

if [ "$DETATCH" == true ]; then
    exit 1
fi
docker-compose logs -f