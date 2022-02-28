#!/bin/bash
# NOTE: Before usage, make sure executable permission are set `chmod +x <name>.sh`

# Help
# TODO update
usage() { echo "Usage: $0 [-s(kip-intro)] [-d(etatch)] [-h(elp)]" 1>&2; exit 1; }

# File count in folder
count() { return "$(find "$1" -type f | wc -l)"; }

# Kill the script
kill() { printf '%s\n' "$1" >&2; exit 1; }

# Variables
SKIP=false
DETATCH=false

DATABASE_BUFFER_DEFAULT=3
DATABASE_BUFFER_HEAVY=60

MIGRATION_BUFFER_DEFAULT=10
MIGRATION_BUFFER_HEAVY=60

# Example: root@remote:/data/app
ENV=

# Initialize all the option variables.
# This ensures we are not contaminated by variables from the environment.
while :; do
  case $1 in
    # Display usage
    -h|-\?|--help)
      usage
      exit
      ;;
    -e|--environment)
      if [ "$2" ]; then
        ENV=$2
        shift
      else
        kill '[ERROR] "-e|--environment" requires a non-empty option argument.'
      fi
      ;;
    -s|--skip-intro)
      SKIP=true
      ;;
    -d|--detatch)
      DETATCH=true
      ;;
    # End of all options.
    --)
      shift
      break
      ;;
    -?*)
      printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
      ;;
    # Default case: No more options, so break out of the loop.
    *)
      break
  esac

  shift
done

# Ensure the script is started as a root user
# [[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit

# START~
if [ "$SKIP" == false ]; then
  echo "[WARNING] This script will completely restart and reset your stack, you have 5 seconds to press CTRL+z"
  sleep 5
fi

docker-compose down --remove-orphans
docker-compose down

resetLocal() {
  # Open data folder
  # chmod -R 777 data
  # Move data to safety
  mkdir -p tmp/scripts/reset/toLoad
  cp -r data/db/toLoad/. tmp/scripts/reset/toLoad/
  # Reset data folder to remote
  rm -Rf data
  git checkout data
  # Move data back
  cp -r tmp/scripts/reset/toLoad/. data/db/toLoad
  # Cleanup
  rm -rf tmp/scripts/reset
  # chmod -R 777 tmp/scripts
  # chmod -R 777 data/db/toLoad


  # Setup database
  docker-compose up -d database
  # NOTE: take into account .gitkeep
  if count ./data/db/toLoad -gt 1; then
    echo "Found data to be imported into the database ..."
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
}

resetToEnv() {
  # Reset data folder to remote
  # chmod -R 777 data
  rm -Rf data
  git checkout data

  echo "Checking out environment to reset ..."
  # TODO how do I def the user
  rsync -azv --partial -e "ssh -i ~dries/.ssh/id_rsa" --exclude 'backups/*' "${ENV}"/data/db ./data

  # Declare other directories you might want to ingest here.
  #rsync -azv --partial -e ssh -r "${ENV}"/data/files/subsidies ./data/files

  # Cleanup
  # chmod -R 777 data/db/toLoad
}

if [ -z "$ENV" ]; then
  resetLocal
else
  resetToEnv
fi

docker-compose up -d
echo "Giving APP a buffer of 5 seconds to complete"
sleep 5

echo "All ready, you can start exploring!"
if [ "$DETATCH" == false ]; then
  docker-compose logs -f
fi
exit