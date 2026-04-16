# EpicBook Ops Runbook

## Stack overview

| Component | Technology | Location |
|---|---|---|
| Reverse proxy | Nginx 1.27 Alpine | Container: epicbook-proxy |
| Application | Node.js 20 + Express | Container: epicbook-app |
| Database | MySQL 8.0 | Container: epicbook-db |
| Host OS | Ubuntu 22.04 | Azure VM: 52.188.23.59 |
| Registry | Azure Container Registry | epicbookregistry.azurecr.io |

---

## 1. Start / stop the stack

```bash
# SSH into VM
ssh -i ~/.ssh/epicbook_key azureuser@52.188.23.59

# Navigate to project
cd ~/epicbook-capstone

# Start stack
docker compose up -d

# Stop stack (keeps volumes)
docker compose down

# Stop stack and DELETE all data (destructive)
docker compose down -v
```

---

## 2. Check stack status

```bash
# All containers and health status
docker compose ps

# Live health endpoint
curl http://localhost/health

# Follow all logs live
docker compose logs -f

# Follow specific service logs
docker compose logs -f app
docker compose logs -f db
docker compose logs -f proxy

# Nginx access log on host
tail -f ~/epicbook-capstone/logs/nginx/access.log

# Nginx error log on host
tail -f ~/epicbook-capstone/logs/nginx/error.log
```

---

## 3. Deploy latest version (manual)

```bash
# SSH into VM
ssh -i ~/.ssh/epicbook_key azureuser@52.188.23.59
cd ~/epicbook-capstone

# Pull latest images from ACR
docker login epicbookregistry.azurecr.io \
  -u epicbookregistry \
  -p <ACR_PASSWORD>

docker compose pull
docker compose up -d
docker image prune -f
```

Or simply push to the `main` branch — the Azure Pipeline handles it automatically.

---

## 4. Rollback procedure

```bash
# SSH into VM
ssh -i ~/.ssh/epicbook_key azureuser@52.188.23.59
cd ~/epicbook-capstone

# List available image tags in ACR
az acr repository show-tags \
  --name epicbookregistry \
  --repository epicbook-app \
  --output table

# Edit docker-compose.yml to pin a specific build ID
# Change: image: epicbookregistry.azurecr.io/epicbook-app:latest
# To:     image: epicbookregistry.azurecr.io/epicbook-app:<BUILD_ID>

# Restart with pinned version
docker compose up -d
```

---

## 5. Rotating secrets

```bash
# Update .env file on VM with new password
nano ~/epicbook-capstone/.env

# Update config.json with new DB password
nano ~/epicbook-capstone/app/config/config.json

# Rebuild and restart app
docker compose up -d --build app

# If rotating MySQL root password, also update DB:
docker exec epicbook-db mysql -uroot -p<OLD_PASSWORD> \
  -e "ALTER USER 'root'@'%' IDENTIFIED BY '<NEW_PASSWORD>';"
```

---

## 6. Log locations

| Log | Location | Access method |
|---|---|---|
| Nginx access | `~/epicbook-capstone/logs/nginx/access.log` | `tail -f` directly |
| Nginx error | `~/epicbook-capstone/logs/nginx/error.log` | `tail -f` directly |
| App requests | Docker stdout | `docker compose logs app` |
| DB server | Docker stdout | `docker compose logs db` |

---

## 7. Backup and restore

```bash
# Run manual backup
~/epicbook-capstone/backups/backup.sh

# List available backups
ls -lh ~/epicbook-capstone/backups/*.sql

# Restore from backup
~/epicbook-capstone/backups/restore.sh \
  ~/epicbook-capstone/backups/bookstore_<TIMESTAMP>.sql
```

### Automated daily backup via cron
```bash
# Add to crontab (runs at 2am daily)
crontab -e
# Add this line:
0 2 * * * /home/azureuser/epicbook-capstone/backups/backup.sh >> /home/azureuser/epicbook-capstone/logs/backup.log 2>&1
```

---

## 8. Common errors and fixes

### App keeps restarting
```bash
docker compose logs app --tail 20
# Usually means DB is not ready yet — wait 30 seconds and check again
docker compose ps
```

### 502 Bad Gateway from Nginx
```bash
# App container is down
docker compose ps
docker compose restart app
```

### 504 Gateway Timeout
```bash
# A route is not sending a response back
# Known issue: DELETE /api/cart/delete has no response body
# Check Nginx error log:
tail ~/epicbook-capstone/logs/nginx/error.log
```

### DB connection refused
```bash
# Check DB is running
docker compose ps db
# Start it if stopped
docker compose start db
# Check DB logs
docker compose logs db --tail 20
```

### Port 80 not accessible from internet
```bash
# Check NSG rule exists
az network nsg rule list \
  --resource-group epicbook-rg \
  --nsg-name SecGroupNet \
  --query "[].{Name:name, Port:destinationPortRange, Access:access}" \
  --output table
```

### Out of disk space
```bash
# Check disk usage
df -h
# Remove unused Docker images
docker image prune -a
# Remove unused volumes (careful - check first)
docker volume ls
```

---

## 9. Reliability test results

### Test 1 — App container restart
- Action: `docker compose restart app`
- Result: App restarted and returned to healthy in ~40 seconds
- Impact: Brief 502 errors during restart, auto-recovered

### Test 2 — DB container stopped
- Action: `docker compose stop db`
- Result: `/health` immediately returned `{"status":"error","db":"unreachable"}`
- App entered restart loop, proxy turned unhealthy
- Recovery: `docker compose start db` — all three containers healthy within 60 seconds

### Test 3 — Full stack bounce
- Action: `docker compose down && docker compose up -d`
- Result: All data persisted in `db_data` named volume
- Stack fully healthy within 60 seconds

