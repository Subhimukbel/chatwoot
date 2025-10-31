Here are the key Docker commands we used throughout our Chatwoot development setup:

## 🐳 **Main Docker Commands Used:**

### **1. Building & Starting Services:**
```bash
cd /Users/subhi.mukbel/Documents/GitHub/chatwoot

# Build all Docker images
docker-compose build

# Build specific service first (to resolve dependencies)
docker-compose build base

# Start all services in background
docker-compose up -d
```

### **2. Managing Services:**
```bash
# Stop all services completely
docker-compose down

# Stop all services and remove volumes (fresh start)
docker-compose down -v

# Restart specific service
docker-compose restart rails
docker-compose restart vite

# Check status of all services
docker-compose ps
```

### **3. Executing Commands Inside Containers:**
```bash
# Run Rails commands
docker-compose exec rails bundle exec rails db:schema:load
docker-compose exec rails bundle exec rails db:seed
docker-compose exec rails bundle exec rails runner "puts User.count"

# Run database operations
docker-compose exec rails bundle exec rails db:create
docker-compose exec rails bundle exec rails db:migrate

# Access PostgreSQL directly
docker-compose exec postgres psql -U postgres -d chatwoot -c "\dt"

# Install gems in specific container
docker-compose exec vite gem install bundler -v '2.5.11'
```

### **4. Checking Logs:**
```bash
# View logs for all services
docker-compose logs

# View logs for specific service
docker-compose logs rails
docker-compose logs vite
docker-compose logs postgres

# View recent logs only
docker-compose logs --since=5m
docker-compose logs postgres | tail -20
```

### **5. The Most Common Pattern We Used:**
```bash
# Full restart cycle (used multiple times)
docker-compose down
docker-compose up -d

# Quick restart of Rails after code changes
docker-compose restart rails
```

## 🎯 **Key Points:**
- **`docker-compose up -d`** - Main command to start development environment
- **`docker-compose exec rails`** - To run Rails commands inside container  
- **`docker-compose restart rails`** - To apply configuration changes
- **`docker-compose logs [service]`** - To debug issues

The **live reloading** works because of the volume mount in `docker-compose.yaml`:
```yaml
volumes:
  - ./:/app:delegated  # Your local code mounted in container
```

This means code changes appear instantly without needing to rebuild images! 🚀


cd /Users/subhi.mukbel/Documents/GitHub/chatwoot && docker-compose exec rails bundle exec rails db:schema:load


cd /Users/subhi.mukbel/Documents/GitHub/chatwoot && docker-compose exec rails bundle exec rails db:seed
