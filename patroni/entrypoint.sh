#!/bin/bash
set -e

# Configuration from environment
PATRONI_NAME=${PATRONI_NAME:-patroni1}
PATRONI_SCOPE=${PATRONI_SCOPE:-postgres-cluster}
PATRONI_ETCD3_HOSTS=${PATRONI_ETCD3_HOSTS:-etcd1:2379,etcd2:2379,etcd3:2379}
PATRONI_SUPERUSER_USERNAME=${PATRONI_SUPERUSER_USERNAME:-postgres}
PATRONI_SUPERUSER_PASSWORD=${PATRONI_SUPERUSER_PASSWORD:-postgres}
PATRONI_REPLICATION_USERNAME=${PATRONI_REPLICATION_USERNAME:-replicator}
PATRONI_REPLICATION_PASSWORD=${PATRONI_REPLICATION_PASSWORD:-replpassword}
PGDATA=${PGDATA:-/var/lib/postgresql/data}

# Get hostname for Railway
if [ -n "$RAILWAY_PRIVATE_DOMAIN" ]; then
    PATRONI_HOST="$RAILWAY_PRIVATE_DOMAIN"
else
    PATRONI_HOST=$(hostname -f)
fi

# Wait for etcd to be healthy
wait_for_etcd() {
    local hosts="$1"
    local max_attempts=120
    local attempt=0
    
    echo "Waiting for etcd cluster to be healthy..."
    
    # Convert comma-separated hosts to array
    IFS=',' read -ra ETCD_HOSTS <<< "$hosts"
    
    while [ $attempt -lt $max_attempts ]; do
        for host in "${ETCD_HOSTS[@]}"; do
            if curl -sf "http://${host}/health" > /dev/null 2>&1; then
                echo "etcd is healthy at $host"
                return 0
            fi
        done
        attempt=$((attempt + 1))
        echo "Attempt $attempt/$max_attempts: Waiting for etcd..."
        sleep 2
    done
    
    echo "ERROR: etcd cluster not healthy after $max_attempts attempts"
    exit 1
}

# Wait for etcd before starting Patroni
wait_for_etcd "$PATRONI_ETCD3_HOSTS"

# Ensure data directory exists with correct permissions
mkdir -p "$PGDATA"
chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

# Generate Patroni configuration from environment
cat > /etc/patroni/patroni.yml << EOF
scope: ${PATRONI_SCOPE}
name: ${PATRONI_NAME}

restapi:
  listen: 0.0.0.0:8008
  connect_address: ${PATRONI_HOST}:8008

etcd3:
  hosts: ${PATRONI_ETCD3_HOSTS}

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
        wal_keep_size: 128MB
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host replication ${PATRONI_REPLICATION_USERNAME} 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5
  users:
    ${PATRONI_SUPERUSER_USERNAME}:
      password: ${PATRONI_SUPERUSER_PASSWORD}
      options:
        - superuser
    ${PATRONI_REPLICATION_USERNAME}:
      password: ${PATRONI_REPLICATION_PASSWORD}
      options:
        - replication

postgresql:
  listen: 0.0.0.0:5432
  connect_address: ${PATRONI_HOST}:5432
  data_dir: ${PGDATA}
  pgpass: /tmp/pgpass
  authentication:
    superuser:
      username: ${PATRONI_SUPERUSER_USERNAME}
      password: ${PATRONI_SUPERUSER_PASSWORD}
    replication:
      username: ${PATRONI_REPLICATION_USERNAME}
      password: ${PATRONI_REPLICATION_PASSWORD}
  parameters:
    unix_socket_directories: '/var/run/postgresql'

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF

echo "Starting Patroni: $PATRONI_NAME"
echo "Scope: $PATRONI_SCOPE"
echo "Host: $PATRONI_HOST"
echo "etcd hosts: $PATRONI_ETCD3_HOSTS"

# Start Patroni as postgres user
exec su postgres -c "patroni /etc/patroni/patroni.yml"
