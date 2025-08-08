#!/bin/bash

set -e

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting wallet-backend startup process...${NC}"

# Validate required env vars
if [ -z "${DATABASE_URL:-}" ]; then
  echo -e "${RED}❌ DATABASE_URL is not set. Ensure Flightcontrol sets it from the RDS service (fromService.value=dbConnectionString).${NC}"
  env | grep -E "^(FC_|PORT=|DB_|DATABASE_)" || true
  exit 1
fi

# Minimal redaction of database URL for diagnostics
MASKED_DB_URL=$(echo "$DATABASE_URL" | sed -E 's#://[^@]*@#://****@#')
echo -e "${YELLOW}Using DATABASE_URL=${MASKED_DB_URL}${NC}"
if [ -n "${DB_HOST:-}" ]; then
  echo -e "${YELLOW}DB_HOST=${DB_HOST}${NC}"
fi

# Function to wait for database connection
wait_for_db() {
    local max_attempts=30
    local attempt=1
    local wait_time=5

    echo -e "${YELLOW}📦 Waiting for database connection...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "${YELLOW}Attempt $attempt/$max_attempts: Testing database connection...${NC}"
        
        # Try to connect to the database using a simple query
        if /app/wallet-backend migrate up --database-url="$DATABASE_URL"; then
            echo -e "${GREEN}✅ Database connection successful!${NC}"
            return 0
        else
            echo -e "${RED}❌ Database connection failed. Waiting ${wait_time}s before retry...${NC}"
            sleep $wait_time
            attempt=$((attempt + 1))
            
            # Exponential backoff (max 30s)
            if [ $wait_time -lt 30 ]; then
                wait_time=$((wait_time + 2))
            fi
        fi
    done
    
    echo -e "${RED}💥 Failed to connect to database after $max_attempts attempts${NC}"
    exit 1
}

# Function to run migrations with retry
run_migrations() {
    local max_attempts=5
    local attempt=1
    
    echo -e "${YELLOW}📊 Running database migrations...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "${YELLOW}Migration attempt $attempt/$max_attempts${NC}"
        
        if /app/wallet-backend migrate up --database-url="$DATABASE_URL"; then
            echo -e "${GREEN}✅ Migrations completed successfully!${NC}"
            return 0
        else
            echo -e "${RED}❌ Migration failed. Waiting 10s before retry...${NC}"
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    echo -e "${RED}💥 Failed to run migrations after $max_attempts attempts${NC}"
    exit 1
}

# Function to ensure channel accounts
ensure_channel_accounts() {
    local max_attempts=3
    local attempt=1
    local num_accounts=${NUMBER_CHANNEL_ACCOUNTS:-15}
    
    echo -e "${YELLOW}🔐 Ensuring channel accounts ($num_accounts)...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "${YELLOW}Channel account attempt $attempt/$max_attempts${NC}"
        
        if /app/wallet-backend channel-account ensure $num_accounts --database-url="$DATABASE_URL"; then
            echo -e "${GREEN}✅ Channel accounts ensured successfully!${NC}"
            return 0
        else
            echo -e "${RED}❌ Channel account setup failed. Waiting 5s before retry...${NC}"
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    echo -e "${RED}💥 Failed to ensure channel accounts after $max_attempts attempts${NC}"
    exit 1
}

# Main startup sequence
echo -e "${GREEN}📋 Starting startup sequence...${NC}"

# Step 1: Wait for database
wait_for_db

# Step 2: Run migrations
run_migrations

# Step 3: Ensure channel accounts
ensure_channel_accounts

# Step 4: Start the server
echo -e "${GREEN}🌐 Starting wallet-backend server...${NC}"
exec /app/wallet-backend serve --database-url="$DATABASE_URL"