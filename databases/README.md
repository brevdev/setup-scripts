# Databases

PostgreSQL and Redis in Docker containers.

## What it installs

- **PostgreSQL 16** - Relational database
- **Redis 7** - In-memory data store
- Both in Docker with persistent storage

## Usage

```bash
bash setup.sh
```

Takes ~1-2 minutes (downloads Docker images).

## What you get

**PostgreSQL:**
- Host: `localhost:5432`
- User: `postgres`
- Password: `postgres`
- Database: `postgres`

**Redis:**
- Host: `localhost:6379`
- No password

## Connect to PostgreSQL

```bash
# Using psql
docker exec -it postgres psql -U postgres

# Or install client
sudo apt install postgresql-client
psql -h localhost -U postgres
```

## Connect to Redis

```bash
# Using redis-cli
docker exec -it redis redis-cli

# Or install client
sudo apt install redis-tools
redis-cli
```

## Manage containers

```bash
docker ps                    # See running containers
docker stop postgres redis   # Stop databases
docker start postgres redis  # Start databases
docker logs postgres         # View logs
docker exec -it postgres bash # Get shell in container
```

