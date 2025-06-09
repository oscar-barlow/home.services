#!/bin/bash -x
echo "=== DNS Generation Script Starting ==="
echo "Current time: $(date)"
echo "Environment variables:"
echo "  DOMAIN: '${DOMAIN}'"
echo "  JELLYFIN_IP: '${JELLYFIN_IP}'"
echo "  PIHOLE_IP: '${PIHOLE_IP}'"
echo "  HELLO_WORLD_IP: '${HELLO_WORLD_IP}'"

# Small delay to ensure environment is fully loaded
sleep 2

echo "Generating DNS configuration..."

echo "Using template: /etc/dnsmasq.d/02-custom-dns.conf.template"
cat /etc/dnsmasq.d/02-custom-dns.conf.template

sed -e "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" \
    -e "s/JELLYFIN_IP_PLACEHOLDER/${JELLYFIN_IP}/g" \
    -e "s/PIHOLE_IP_PLACEHOLDER/${PIHOLE_IP}/g" \
    -e "s/HELLO_WORLD_IP_PLACEHOLDER/${HELLO_WORLD_IP}/g" \
    /etc/dnsmasq.d/02-custom-dns.conf.template > /etc/dnsmasq.d/02-custom-dns.conf

echo \n
echo "Generated file contents:"
cat /etc/dnsmasq.d/02-custom-dns.conf
echo "=== DNS Generation Script Complete ==="