# OpenFn Deployment Documentation

This documentation covers the deployment of OpenFn (Lightning + DevTools + Worker) using Docker. This setup is designed to handle 20,000 transactions per day with proper scaling and monitoring.

## Architecture Overview

### Components
- **Lightning**: Main application service (exposed on port 8070)
- **DevTools**: Development and debugging interface
- **Worker**: Job execution engine (scaled based on load)
- **PostgreSQL**: Primary database (persistent storage)
- **Redis**: Queue and caching layer
- **Nginx**: Reverse proxy (handles SSL termination for openfn.sidainfo.org)

### Deployment Files
- `docker-compose.yml` — Development environment setup (single-host)
- `docker-stack.yml` — Production stack for Docker Swarm with secrets management
- `.env.example` — Environment variables template
- `deploy-swarm.ps1` — PowerShell deployment helper script
- `nginx_openfn.conf` — Nginx configuration for SSL termination

## Quick Start (Development)

1. Clone this repository:
```bash
git clone https://github.com/emerick-pro/openFn-docker.git
cd openFn-docker
```

2. Copy and configure environment file:
```bash
cp .env.example .env
# Edit .env with your values
```

3. Start the stack:
```bash
docker-compose up -d
```

4. Verify the deployment:
```bash
docker-compose ps
docker-compose logs -f lightning
curl http://localhost:8070  # Should return Lightning's response
```

## Production Deployment

### Prerequisites
- Docker Engine 20.10+
- Nginx (for SSL termination)
- Domain name pointed to your server (openfn.sidainfo.org)
- SSL certificate (Let's Encrypt recommended)

### Initial Setup

1. Initialize Docker Swarm (if not already done):
```bash
docker swarm init --advertise-addr <MANAGER-IP>
```

2. Create required secrets:
```powershell
# On Windows (using provided script)
mkdir secrets
# Create secrets/postgres_password.txt and secrets/app_secret.txt
./deploy-swarm.ps1

# Or on Linux:
echo "your-strong-postgres-password" | docker secret create postgres_password -
echo "your-strong-app-secret" | docker secret create app_secret -
```

3. Deploy the stack:
```bash
docker stack deploy -c docker-stack.yml openfn
```

4. Verify deployment:
```bash
docker stack ps openfn
docker service ls
```

Note: this Swarm stack no longer includes Traefik. The `lightning` service publishes port 8070 on the swarm nodes so a host-level Nginx (or other TLS terminator) can proxy to `http://<NODE-IP>:8070` or `http://127.0.0.1:8070` on the node where you run Nginx. If you prefer an in-cluster edge router, consider re-adding Traefik or using an ingress controller.

### Nginx Configuration

1. Install Nginx and Certbot:
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx
```

2. Place the Nginx configuration:
```bash
sudo cp nginx_openfn.conf /etc/nginx/sites-available/openfn.sidainfo.org
sudo ln -s /etc/nginx/sites-available/openfn.sidainfo.org /etc/nginx/sites-enabled/
```

3. Obtain SSL certificate:
```bash
sudo certbot --nginx -d openfn.sidainfo.org
```

4. Verify Nginx configuration and restart:
```bash
sudo nginx -t
sudo systemctl restart nginx
```

### Nginx + Certbot helper scripts

This repository includes helper scripts to install certbot, obtain certificates and test renewal. They live in the `scripts/` folder:

- `scripts/install_certbot_ubuntu.sh` — Installs Nginx and certbot (Ubuntu/Debian).
- `scripts/obtain_cert.sh` — Copies `nginx_openfn.conf` into `/etc/nginx/sites-available`, enables the site, reloads Nginx and runs `certbot --nginx` to obtain certificates. Usage:

```bash
# Make executable
chmod +x scripts/obtain_cert.sh

# Obtain a staging certificate (use for testing to avoid Let's Encrypt rate limits):
sudo ./scripts/obtain_cert.sh --staging --email ops@sidainfo.org --domain openfn.sidainfo.org

# Obtain a real certificate:
sudo ./scripts/obtain_cert.sh --email ops@sidainfo.org --domain openfn.sidainfo.org
```

- `scripts/renew_cert_check.sh` — Runs `certbot renew --dry-run` and reloads Nginx if successful. Add this to cron or run manually to verify renewal.

Notes:
- The `nginx_openfn.conf` included in this repo points to the typical certbot paths under `/etc/letsencrypt/live/<domain>/...` so certbot will correctly populate those files when it runs with the `--nginx` installer.
- Use the `--staging` flag for testing to avoid hitting production rate limits.

### Compose variant for Nginx (no Traefik)

If you plan to use Nginx for TLS termination (certbot), use `docker-compose-nginx.yml` which omits the Traefik service so Nginx can bind ports 80/443 on the host. Start with:

```bash
docker-compose -f docker-compose-nginx.yml up -d
```

This starts `lightning` bound to host port `8070`, which the `nginx_openfn.conf` proxies to at `http://127.0.0.1:8070`.

## Scaling and Monitoring

### Worker Scaling
- **Manual scaling**:
```bash
docker service scale openfn_worker=5
```
- **Automatic scaling**: Implement based on queue metrics (see Monitoring section)

### Monitoring Stack

1. Key Metrics to Monitor:
- CPU and Memory usage per service
- PostgreSQL connections and query performance
- Redis queue length
- Worker job processing rate
- HTTP response times

2. Recommended Tools:
- Prometheus: Metrics collection
- Grafana: Visualization
- Alertmanager: Alert routing
- Node Exporter: Host metrics
- cAdvisor: Container metrics

### Example Prometheus Alerts:
- Worker queue depth > 1000 for 5 minutes
- Job processing latency > 30s
- Database connections > 80% capacity
- Memory usage > 85% on any service

## Backup and Recovery

### Database Backups

1. Automated backup script (place in /etc/cron.daily/openfn-backup):
```bash
#!/bin/bash
BACKUP_DATE=$(date +%Y%m%d)
PGUSER="openfn"
BACKUP_PATH="/var/backups/openfn"

# Logical backup
docker exec openfn_postgres_1 pg_dump -U $PGUSER openfn_prod > \
  $BACKUP_PATH/openfn_${BACKUP_DATE}.sql

# Rotate backups (keep last 7 days)
find $BACKUP_PATH -name "openfn_*.sql" -mtime +7 -delete
```

2. Enable backup script:
```bash
sudo chmod +x /etc/cron.daily/openfn-backup
```

### Restore Procedure
```bash
# Stop services
docker service scale openfn_lightning=0 openfn_worker=0

# Restore database
cat backup.sql | docker exec -i openfn_postgres_1 psql -U openfn openfn_prod

# Restart services
docker service scale openfn_lightning=2 openfn_worker=3
```

## Security Best Practices

1. **Network Security**:
   - Use Docker secrets for sensitive data
   - Enable TLS 1.2+ only in Nginx
   - Implement proper network segmentation
   - Regular security updates

2. **Access Control**:
   - Minimal container privileges
   - Regular audit of user access
   - Secure Docker daemon access

3. **Monitoring and Logging**:
   - Centralized logging (ELK/Graylog)
   - Security event monitoring
   - Regular log review

4. **Container Security**:
   - Regular image updates
   - Vulnerability scanning (Trivy)
   - Immutable containers

## Maintenance Procedures

### Regular Updates
```bash
# Pull latest images
docker-compose pull  # (dev)
docker service update --image openfn/lightning:latest openfn_lightning  # (prod)

# Security updates on host
sudo apt update && sudo apt upgrade -y
```

### Health Checks
```bash
# Check service health
docker service ls
docker service ps openfn_lightning
docker service ps openfn_worker

# Check logs
docker service logs openfn_lightning
```

## Troubleshooting

Common issues and solutions:

1. **Worker Connection Issues**:
   - Check Redis connectivity
   - Verify worker logs
   - Ensure proper network access

2. **Database Performance**:
   - Monitor connection count
   - Check slow query log
   - Verify disk space

3. **Memory Issues**:
   - Review service limits
   - Check swap usage
   - Monitor OOM kills

## Migration to Kubernetes

Future migration path to Kubernetes available. Key steps:

1. Export data
2. Deploy k8s manifests
3. Import data
4. Switch DNS
5. Verify functionality

Detailed k8s migration guide available upon request.

## Support and Resources

- [OpenFn Documentation](https://docs.openfn.org)
- [Docker Documentation](https://docs.docker.com)
- [Nginx Documentation](https://nginx.org/en/docs/)

## Version History

- 2025-11-06: Initial deployment setup
- Added Nginx configuration for openfn.sidainfo.org
- Configured for 20k transactions/day capacity

For technical support, contact your system administrator or OpenFn support team.

#   o p e n F n - d o c k e r 
 
 