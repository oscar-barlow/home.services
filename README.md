# home.services

Containerised services that can run on a Raspberry Pi on a home network. Paired with a systemd unit so they launch on machine startup, with logs sent to systemout so that you can explore them with `journalctl`.

## services

### pihole
Using the instructions from the official docker-pi-hole repo to run a customised pi-hole.

