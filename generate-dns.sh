#!/bin/bash
echo "Generating DNS configuration..."

sed -e "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" \
    -e "s/JELLYFIN_IP_PLACEHOLDER/${JELLYFIN_IP}/g" \
    -e "s/PIHOLE_IP_PLACEHOLDER/${PIHOLE_IP}/g" \
    -e "s/HELLO_WORLD_IP_PLACEHOLDER/${HELLO_WORLD_IP}/g" \
    /etc/dnsmasq.d/02-custom-dns.conf.template > /etc/dnsmasq.d/02-custom-dns.conf

echo "DNS configuration generated successfully."