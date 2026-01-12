#!/bin/sh
set -e

# Wait for DNS resolution of peers (Railway internal networking)
wait_for_dns() {
    local host=$1
    local max_attempts=60
    local attempt=0
    
    echo "Waiting for DNS resolution of $host..."
    while [ $attempt -lt $max_attempts ]; do
        if getent hosts "$host" > /dev/null 2>&1; then
            echo "DNS resolution successful for $host"
            return 0
        fi
        attempt=$((attempt + 1))
        echo "Attempt $attempt/$max_attempts: Waiting for $host..."
        sleep 2
    done
    
    echo "WARNING: Could not resolve $host, proceeding anyway..."
    return 0
}

# Set defaults
ETCD_NAME=${ETCD_NAME:-etcd1}
ETCD_DATA_DIR=${ETCD_DATA_DIR:-/var/lib/etcd}

# Ensure data directory exists with correct permissions
mkdir -p "$ETCD_DATA_DIR"

# Parse cluster members from ETCD_INITIAL_CLUSTER and wait for DNS
if [ -n "$ETCD_INITIAL_CLUSTER" ]; then
    echo "Waiting for cluster peers..."
    # Extract hostnames from cluster config (format: name=http://host:port,...)
    echo "$ETCD_INITIAL_CLUSTER" | tr ',' '\n' | while read -r member; do
        host=$(echo "$member" | sed 's/.*http:\/\/\([^:]*\):.*/\1/')
        if [ -n "$host" ] && [ "$host" != "$HOSTNAME" ]; then
            wait_for_dns "$host"
        fi
    done
fi

echo "Starting etcd node: $ETCD_NAME"
echo "Data directory: $ETCD_DATA_DIR"
echo "Initial cluster: $ETCD_INITIAL_CLUSTER"

# Start etcd with environment variables
exec etcd \
    --name "$ETCD_NAME" \
    --data-dir "$ETCD_DATA_DIR" \
    --listen-client-urls "${ETCD_LISTEN_CLIENT_URLS:-http://0.0.0.0:2379}" \
    --advertise-client-urls "${ETCD_ADVERTISE_CLIENT_URLS:-http://${HOSTNAME}:2379}" \
    --listen-peer-urls "${ETCD_LISTEN_PEER_URLS:-http://0.0.0.0:2380}" \
    --initial-advertise-peer-urls "${ETCD_INITIAL_ADVERTISE_PEER_URLS:-http://${HOSTNAME}:2380}" \
    --initial-cluster "${ETCD_INITIAL_CLUSTER}" \
    --initial-cluster-token "${ETCD_INITIAL_CLUSTER_TOKEN:-etcd-cluster}" \
    --initial-cluster-state "${ETCD_INITIAL_CLUSTER_STATE:-new}"
