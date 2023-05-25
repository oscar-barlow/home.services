# home.services

Containerised services that can run on a Raspberry Pi on a home network. Paired with a systemd unit so they launch on machine startup, with logs sent to systemout so that you can explore them with `journalctl`.

## setup
1. copy the systemd unit to the appropriate place in the file system: `sudo cp ...`
2. reload systemd units:
2. enable the systemd unit if this is first-time setup, otherwise you may just want to execute the unit 

The docker services are configured with a restart policy of `unless-stopped`, so that you don't have to figure out how to squash them if you decide you don't want to run one any more. This means there are two levels of guarantee to the operational resilience of these services. If the services crash, the docker daemon will restart them. On the other hand, if the pi restarts, the systemd unit will restart the services. Most of the safety is provided by the docker daemon, systemd is a nice backup.


## services

### pihole
Using the instructions from the official docker-pi-hole repo to run a customised pi-hole.

