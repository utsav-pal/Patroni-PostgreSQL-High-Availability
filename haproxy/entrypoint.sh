#!/bin/bash
set -e

# Get Patroni hosts from environment or use defaults
# For Railway: use RAILWAY_PRIVATE_DOMAIN format (servicename.railway.internal)
# For local Docker: use container hostnames (patroni1, patroni2)
PATRONI1_HOST=${PATRONI1_HOST:-patroni1}
PATRONI2_HOST=${PATRONI2_HOST:-patroni2}

# Wait for at least one Patroni node to be available
wait_for_patroni() {
    local max_attempts=120
    local attempt=0
    
    echo "Waiting for Patroni nodes to be available..."
    echo "PATRONI1_HOST: $PATRONI1_HOST"
    echo "PATRONI2_HOST: $PATRONI2_HOST"
    
    while [ $attempt -lt $max_attempts ]; do
        # Check if any Patroni REST API is responding
        if curl -sf "http://${PATRONI1_HOST}:8008/health" > /dev/null 2>&1; then
            echo "Patroni node 1 is available at $PATRONI1_HOST"
            return 0
        fi
        if curl -sf "http://${PATRONI2_HOST}:8008/health" > /dev/null 2>&1; then
            echo "Patroni node 2 is available at $PATRONI2_HOST"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo "Attempt $attempt/$max_attempts: Waiting for Patroni..."
        sleep 2
    done
    
    echo "WARNING: No Patroni nodes responded, starting HAProxy anyway..."
    return 0
}

# Generate HAProxy config with actual hostnames by replacing placeholders
generate_config() {
    echo "Generating HAProxy config..."
    echo "  PATRONI1_HOST: $PATRONI1_HOST"
    echo "  PATRONI2_HOST: $PATRONI2_HOST"
    
    # Replace placeholders in the template
    sed -e "s/PATRONI1_HOST_PLACEHOLDER/${PATRONI1_HOST}/g" \
        -e "s/PATRONI2_HOST_PLACEHOLDER/${PATRONI2_HOST}/g" \
        /usr/local/etc/haproxy/haproxy.cfg > /tmp/haproxy.cfg
    
    # Move back to original location
    mv /tmp/haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
    
    echo "HAProxy config generated successfully"
}

# Wait for Patroni nodes
wait_for_patroni

# Generate config with actual hostnames
generate_config

echo "Starting HAProxy..."
echo "Primary (read-write) port: 5432"
echo "Replica (read-only) port: 5433"
echo "Stats dashboard port: 8404"

# Start HAProxy
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg
