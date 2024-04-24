#!/bin/bash

# Prompt user if using Docker
read -p "Are you using Docker to run MySQL? (y/n): " USE_DOCKER

# Load database configuration from database.yml
DATABASE_YML="config/database.yml"
HOST=$(ruby -ryaml -e "puts YAML.load_file('$DATABASE_YML', aliases: true)['development']['host']")
USERNAME=$(ruby -ryaml -e "puts YAML.load_file('$DATABASE_YML', aliases: true)['development']['username']")
PASSWORD=$(ruby -ryaml -e "puts YAML.load_file('$DATABASE_YML', aliases: true)['development']['password']")
PORT=$(ruby -ryaml -e "puts YAML.load_file('$DATABASE_YML', aliases: true)['development']['port']")

# Function to create database using Docker
create_database_with_docker() {
    DOCKER_CONTAINER_NAME=$1
    docker exec -i $DOCKER_CONTAINER_NAME mysql -h$HOST -u$USERNAME -p$PASSWORD -P$PORT < db/sql/load_databases_tables.sql
}

# Function to create database without Docker
create_database_without_docker() {
    echo "Creating database..."
    mysql -h$HOST -u$USERNAME -p$PASSWORD -P$PORT < db/sql/load_databases_tables.sql
}

# Check if using Docker or not
if [ "$USE_DOCKER" == "y" ]; then
    read -p "Enter the name of your MySQL Docker container: " DOCKER_CONTAINER_NAME
    create_database_with_docker $DOCKER_CONTAINER_NAME
else
    create_database_without_docker
fi

# Print message
echo "The database named 'databases' has been created."
