#!/bin/bash

env_dir="${PWD}/test-env"

# Function to execute custom commands before exiting
down() {
	docker compose --env-file=$env_dir/.env.dev -f $env_dir/docker-compose.yml down --remove-orphans
	# remove the docker runtime part
    docker volume rm docker_docker-runtime
}

# Register the cleanup function to be called on EXIT
trap down EXIT

mkdir -p $PWD/.device/sysroot
docker compose --env-file=$env_dir/.env.dev -f $env_dir/docker-compose.yml run -e DEV_USER=$(id -u) -e DEV_GROUP=$(id -g) sotactl $@
