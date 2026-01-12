FROM quay.io/coreos/etcd:v3.5.12

# Add health check script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# etcd ports
EXPOSE 2379 2380

ENTRYPOINT ["/entrypoint.sh"]
