FROM postgres:16-bookworm

# Install Python and Patroni dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-psycopg2 \
    python3-yaml \
    curl \
    jq \
    && pip3 install --break-system-packages patroni[etcd3] \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration and entrypoint
COPY patroni.yml /etc/patroni/patroni.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Patroni REST API and PostgreSQL ports
EXPOSE 5432 8008

ENTRYPOINT ["/entrypoint.sh"]
