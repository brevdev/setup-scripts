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
- Password: Auto-generated (stored in `~/.db_passwords.env`)
- Database: `postgres`
- SSL certificates: `~/database_certs/postgres/`

**Redis:**
- Host: `localhost:6379`
- Password: Auto-generated (stored in `~/.db_passwords.env`)
- TLS certificates: `~/database_certs/redis/`

## Access & Remote Access

### Local Access

Both services are bound to `localhost` (127.0.0.1) for security and use SSL/TLS encryption:

```bash
# PostgreSQL
psql -h localhost -U postgres

# Redis
redis-cli -h localhost
```

### Remote Access via SSH Port Forwarding

For secure remote access, use SSH port forwarding:

```bash
# From your local machine - PostgreSQL
ssh -L 5432:localhost:5432 user@your-server

# From your local machine - Redis
ssh -L 6379:localhost:6379 user@your-server

# Then connect from your local machine
psql -h localhost -U postgres
redis-cli -h localhost
```

## Retrieve Passwords

Passwords are stored securely in `~/.db_passwords.env`:

```bash
# View PostgreSQL password
grep POSTGRES_PASSWORD ~/.db_passwords.env

# View Redis password
grep REDIS_PASSWORD ~/.db_passwords.env

# Or view the entire file
cat ~/.db_passwords.env
```

## Connect to PostgreSQL

```bash
# Using psql
psql -h localhost -U postgres
# Enter password when prompted (retrieve from ~/.db_passwords.env)

# Or using Docker exec (no password needed)
docker exec -it postgres psql -U postgres

# Or install client
sudo apt install postgresql-client
psql -h localhost -U postgres
```

**Using password from environment:**
```bash
source ~/.db_passwords.env
psql -h localhost -U postgres -W
# Enter password: $POSTGRES_PASSWORD
```

## Connect to Redis

```bash
# Using redis-cli
redis-cli -h localhost
# Enter password: AUTH <password> (retrieve from ~/.db_passwords.env)

# Or using Docker exec (no password needed)
docker exec -it redis redis-cli

# Or install client
sudo apt install redis-tools
redis-cli -h localhost
```

**Using password from environment:**
```bash
source ~/.db_passwords.env
redis-cli -h localhost -a "$REDIS_PASSWORD"
```

## Connection Strings

**PostgreSQL:**
```bash
# From environment file
source ~/.db_passwords.env
export PGPASSWORD="$POSTGRES_PASSWORD"
psql -h localhost -U postgres -d postgres
```

**Redis:**
```bash
# From environment file
source ~/.db_passwords.env
redis-cli -h localhost -a "$REDIS_PASSWORD"

## Manage containers

```bash
docker ps                    # See running containers
docker stop postgres redis   # Stop databases
docker start postgres redis  # Start databases
docker logs postgres         # View logs
docker logs redis            # View Redis logs
docker exec -it postgres bash # Get shell in container
docker exec -it redis redis-cli # Redis CLI
```

