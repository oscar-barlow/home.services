#!/bin/bash

sed "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g; \
     s/JELLYFIN_IP_PLACEHOLDER/${JELLYFIN_IP}/g; \
     s/PIHOLE_IP_PLACEHOLDER/${PIHOLE_IP}/g; \
     s/HELLO_WORLD_IP_PLACEHOLDER/${HELLO_WORLD_IP}/g" \
   /etc/dnsmasq.d/02-custom-dns.conf.template >/etc/dnsmasq.d/02-custom-dns.conf
