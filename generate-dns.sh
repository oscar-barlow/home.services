#!/bin/bash
echo "Generating DNS configuration..."

sed "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g; \
     s/JELLYFIN_IP_PLACEHOLDER/${JELLYFIN_IP}/g; \
     s/PIHOLE_IP_PLACEHOLDER/${PIHOLE_IP}/g; \
   /etc/dnsmasq.d/02-custom-dns.conf.template > /etc/dnsmasq.d/02-custom-dns.conf"

echo "DNS configuration generated successfully."
