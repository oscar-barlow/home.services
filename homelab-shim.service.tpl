[Unit]
Description=Homelab macvlan shim interface
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'ip link add homelab-shim link INTERFACE type macvlan mode bridge && ip addr add 192.168.1.254/32 dev homelab-shim && ip link set homelab-shim up && ip route add 192.168.1.192/26 dev homelab-shim'
ExecStop=/sbin/ip link del homelab-shim

[Install]
WantedBy=multi-user.target