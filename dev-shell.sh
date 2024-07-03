#!/bin/bash

# Function to execute custom commands before exiting
down() {
	docker compose --env-file=$PWD/docker/.env.dev -f $PWD/docker/docker-compose.yml down --remove-orphans
}

# Register the cleanup function to be called on EXIT
trap down EXIT

mkdir -p $PWD/.device
docker compose --env-file=$PWD/docker/.env.dev -f $PWD/docker/docker-compose.yml run -e DEV_USER=$(id -u) -e DEV_GROUP=$(id -g) sotactl
