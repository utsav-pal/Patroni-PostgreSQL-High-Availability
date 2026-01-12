FROM haproxy:2.9-bookworm

# Switch to root to install packages
USER root

# Install utilities for health checks and templating
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gettext-base \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# HAProxy ports
# 5432 - Primary (read-write)
# 5433 - Replicas (read-only)
# 8404 - Stats dashboard
EXPOSE 5432 5433 8404

# Stay as root since entrypoint needs to generate config
ENTRYPOINT ["/entrypoint.sh"]
