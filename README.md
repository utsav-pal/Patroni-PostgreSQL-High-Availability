# 🐘 Patroni PostgreSQL High Availability - Railway Template

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/patroni-ha)

Production-ready PostgreSQL High Availability cluster with automatic failover using Patroni, etcd, and HAProxy.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│                 Your Application                │
│                       ↓                         │
│              ┌──────────────┐                   │
│              │   HAProxy    │ ← Load Balancer   │
│              │  :5432/:5433 │                   │
│              └──────────────┘                   │
│                   ↓    ↓                        │
│    ┌────────────────┐  ┌────────────────┐      │
│    │   PostgreSQL   │  │   PostgreSQL   │      │
│    │   + Patroni    │  │   + Patroni    │      │
│    │   (Primary)    │  │   (Replica)    │      │
│    └────────────────┘  └────────────────┘      │
│            ↓                   ↓                │
│    ┌──────────┬───────────┬──────────┐         │
│    │  etcd1   │   etcd2   │  etcd3   │         │
│    └──────────┴───────────┴──────────┘         │
│         Distributed Configuration Store         │
└─────────────────────────────────────────────────┘
```

## ✨ Features

- **Automatic Failover**: If primary fails, replica is promoted within 30 seconds
- **Zero-Downtime Deployments**: HAProxy health checks ensure smooth transitions
- **Read/Write Splitting**: Port 5432 for writes, Port 5433 for read replicas
- **Persistent Storage**: Volumes for both etcd and PostgreSQL data
- **Private Networking**: All internal communication via Railway private network

## 🚀 Quick Start

### Deploy to Railway

1. Click the "Deploy on Railway" button above
2. Configure your passwords (or use auto-generated secrets)
3. Wait for all services to start (2-3 minutes)
4. Connect to HAProxy's public endpoint

### Local Development

```bash
# Clone the repository
git clone https://github.com/utsav-pal/Patroni-PostgreSQL-High-Availability.git
cd Patroni-PostgreSQL-High-Availability

# Start the cluster
docker compose up -d

# Check cluster status
docker compose exec patroni1 patronictl list

# Connect to PostgreSQL (local ports are 15432/15433)
psql -h localhost -p 15432 -U postgres -W
# Password: secretpassword
```

## 📡 Connection Details

| Endpoint | Port | Purpose |
|----------|------|---------|
| HAProxy Primary | 5432 | Read-Write (connects to leader) |
| HAProxy Replica | 5433 | Read-Only (load balanced) |
| HAProxy Stats | 8404 | Monitoring dashboard |

### Connection String

```
# Primary (read-write)
postgresql://postgres:YOUR_PASSWORD@haproxy.railway.internal:5432/postgres

# Replica (read-only, for queries)
postgresql://postgres:YOUR_PASSWORD@haproxy.railway.internal:5433/postgres
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PATRONI_SUPERUSER_PASSWORD` | Auto-generated | PostgreSQL superuser password |
| `PATRONI_REPLICATION_PASSWORD` | Auto-generated | Replication user password |
| `PATRONI_SCOPE` | `postgres-ha` | Cluster name |

### Volumes

| Service | Mount Path | Purpose |
|---------|------------|---------|
| etcd1/2/3 | `/var/lib/etcd` | Cluster state |
| patroni1/2 | `/var/lib/postgresql/data` | Database files |

## 🧪 Testing Failover

```bash
# 1. Check current cluster state
docker compose exec patroni1 patronictl list

# 2. Identify the leader and stop it
docker compose stop patroni1

# 3. Wait 30 seconds, verify new leader
docker compose exec patroni2 patronictl list

# 4. Verify connection still works
psql -h localhost -p 15432 -U postgres -c "SELECT pg_is_in_recovery();"
# Should return 'f' (false = primary)

# 5. Bring back old leader (becomes replica)
docker compose start patroni1
```

## 📊 Monitoring

Access HAProxy stats dashboard at `http://localhost:8404/stats`

Check cluster health:

```bash
# Patroni cluster status
docker compose exec patroni1 patronictl list

# etcd cluster health
docker compose exec etcd1 etcdctl endpoint health
```

## 🏷️ Services

| Service | Image | Purpose |
|---------|-------|---------|
| etcd1, etcd2, etcd3 | quay.io/coreos/etcd:v3.5.12 | Distributed consensus |
| patroni1, patroni2 | postgres:16 + Patroni | PostgreSQL HA |
| haproxy | haproxy:2.9 | Load balancer |

## 📜 License

MIT License - Feel free to use in your Railway templates!

## 🤝 Contributing

Contributions welcome! Please open an issue or PR.
