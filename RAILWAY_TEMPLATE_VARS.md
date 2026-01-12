# Railway Template Variables

Use these when creating the template in Railway's Template Composer.

## Quick Setup Guide

When adding each service in Railway's template composer:

1. Add the service from your GitHub repo
2. Set the **Root Directory** to the service folder (e.g., `patroni` for Patroni nodes)
3. Add the environment variables listed below
4. Attach a volume where specified

---

## 🔐 Shared Variables (Set Once, Reference Everywhere)

Create these as **Shared Variables** in your template:

| Variable | Value | Description |
|----------|-------|-------------|
| `PATRONI_SUPERUSER_PASSWORD` | `${{secret(32)}}` | PostgreSQL superuser password |
| `PATRONI_REPLICATION_PASSWORD` | `${{secret(32)}}` | Replication user password |
| `ETCD_INITIAL_CLUSTER_TOKEN` | `${{secret(16)}}` | etcd cluster token |
| `PATRONI_SCOPE` | `postgres-ha` | Cluster name |

---

## 📦 Service-Specific Variables

### etcd1 (Root Directory: not needed - uses Docker image)

```
ETCD_NAME=etcd1
ETCD_DATA_DIR=/var/lib/etcd
ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379
ETCD_ADVERTISE_CLIENT_URLS=http://${{RAILWAY_PRIVATE_DOMAIN}}:2379
ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380
ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${{RAILWAY_PRIVATE_DOMAIN}}:2380
ETCD_INITIAL_CLUSTER=etcd1=http://etcd1.railway.internal:2380,etcd2=http://etcd2.railway.internal:2380,etcd3=http://etcd3.railway.internal:2380
ETCD_INITIAL_CLUSTER_TOKEN=${{shared.ETCD_INITIAL_CLUSTER_TOKEN}}
ETCD_INITIAL_CLUSTER_STATE=new
```

**Volume:** `/var/lib/etcd`

### etcd2 (same as etcd1, change name)

```
ETCD_NAME=etcd2
```

(All other variables same as etcd1)

### etcd3 (same as etcd1, change name)

```
ETCD_NAME=etcd3
```

(All other variables same as etcd1)

---

### patroni1 (Root Directory: `patroni`)

```
PATRONI_NAME=patroni1
PATRONI_SCOPE=${{shared.PATRONI_SCOPE}}
PATRONI_ETCD3_HOSTS=etcd1.railway.internal:2379,etcd2.railway.internal:2379,etcd3.railway.internal:2379
PATRONI_SUPERUSER_USERNAME=postgres
PATRONI_SUPERUSER_PASSWORD=${{shared.PATRONI_SUPERUSER_PASSWORD}}
PATRONI_REPLICATION_USERNAME=replicator
PATRONI_REPLICATION_PASSWORD=${{shared.PATRONI_REPLICATION_PASSWORD}}
PGDATA=/var/lib/postgresql/data
```

**Volume:** `/var/lib/postgresql/data`

### patroni2 (same as patroni1, change name)

```
PATRONI_NAME=patroni2
```

(All other variables same as patroni1)

---

### haproxy (Root Directory: `haproxy`)

```
PATRONI1_HOST=${{patroni1.RAILWAY_PRIVATE_DOMAIN}}
PATRONI2_HOST=${{patroni2.RAILWAY_PRIVATE_DOMAIN}}
```

**Public Networking:** Enable ports 5432, 5433, and 8404

---

## 🔗 Connection Strings for Users

After deployment, users connect via:

```
# Primary (read-write)
postgresql://postgres:PASSWORD@haproxy.railway.internal:5432/postgres

# Replica (read-only, load balanced)
postgresql://postgres:PASSWORD@haproxy.railway.internal:5433/postgres
```

For external access, use the HAProxy public domain provided by Railway.
