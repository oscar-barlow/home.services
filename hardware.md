# Hardware

## N100 Mini PC Hardware Setup

- **Model**: Geekom Mini Air12-0 (N100)
- **Storage**: 256GB total
- **Ethernet**: Motorcomm YT6801 Gigabit Controller (PCI ID: 1f0a:6801)
- **Issue**: No mainline Linux driver support

## Operating System Installation

### Pre-installation
- System comes with Windows pre-installed
- Uses UEFI boot with existing EFI System Partition
- Secure Boot may need to be disabled for easier installation

### Debian Installation Process
1. **Download Debian ISO**: Use standard amd64 netinst ISO (tested with debian-12.11.0-amd64-netinst.iso)
2. **Create bootable USB**: Use `dd` command or Rufus to write ISO to USB drive
3. **Boot from USB**: Access boot menu (F12/F10/ESC) during startup to select USB drive

### Partitioning Strategy
- **Dual-boot setup** preserving Windows
- **Windows partition**: Resized to 80GB (from original ~255GB)
- **Debian root (/)**: ~165GB ext4 filesystem
- **Swap**: ~8-10GB
- **Keep existing**: EFI System Partition, Microsoft Reserved, Windows Recovery partitions

### Installation Notes
- **Network**: Ethernet not detected during installation (driver issue)
- **Workaround**: Skip network configuration, complete minimal installation
- **Software selection**: SSH server + standard system utilities only (no desktop environment)
- **Post-install**: Configure WiFi or USB ethernet for connectivity

### GRUB Configuration
- GRUB automatically detects Windows for dual-boot menu
- Configure auto-boot to Debian:
  ```bash
  sudo nano /etc/default/grub
  # Set GRUB_DEFAULT=0 and GRUB_TIMEOUT=5
  sudo update-grub
  ```
- Access GRUB menu: Hold Shift during boot

### Post-Installation Setup
- **User privileges**: Add user to sudo group with `usermod -aG sudo username`
- **WiFi**: Configure with wpasupplicant for initial connectivity
- **Power management**: Disable WiFi power management for better performance:
  ```bash
  sudo iwconfig wlp2s0 power off
  ```

## Ethernet Driver Setup

The YT6801 ethernet controller requires a third-party driver due to lack of mainline kernel support.

### Install Driver

```bash
wget https://www.motor-comm.com/Public/Uploads/uploadfile/files/20250430/yt6801-linux-driver-1.0.30.zip
unzip yt6801-linux-driver-1.0.30.zip
cd yt6801-linux-driver-1.0.30
sudo su -
./yt_nic_install.sh
```

### Sign Module for Secure Boot

```bash
openssl req -new -x509 -newkey rsa:2048 -keyout /root/MOK.priv -outform DER -out /root/MOK.der -nodes -days 36500 -subj "/CN=Local MOK/"
mokutil --import /root/MOK.der
/usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 /root/MOK.priv /root/MOK.der /lib/modules/$(uname -r)/kernel/drivers/net/ethernet/motorcomm/yt6801.ko
reboot
```

During boot, enroll the MOK key when prompted.

### Configure Interface

```bash
sudo modprobe yt6801
sudo ip link set enp1s0 up
sudo dhclient enp1s0
```

Add to `/etc/network/interfaces`:
```
auto enp1s0
iface enp1s0 inet dhcp
```

## Docker Swarm Node Labels

When joining nodes to the Docker Swarm, use standardized labels to identify hardware and capacity:

### Hardware Labels (`LABEL_HARDWARE`)
- `rpi-4` - Raspberry Pi 4  
- `n100` - N100 Mini PC (like Geekom Mini Air12-0)

### Class Labels (`LABEL_CLASS`)
- `extra-small` - Minimal resource nodes
- `small` - Low resource nodes
- `medium` - Moderate resource nodes
- `large` - High resource nodes
- `extra-large` - Maximum resource nodes

### Usage Examples
```bash
# Initialize swarm with labels
make swarm-init LABEL_HARDWARE=n100 LABEL_CLASS=medium

# Join worker with labels  
make swarm-join MANAGER_IP=192.168.1.10 TOKEN=SWMTKN-... LABEL_HARDWARE=rpi-4 LABEL_CLASS=small
```

## Notes

- Keep WiFi configuration as backup
- Ethernet recommended for Docker Swarm networking performance
- Driver may need rebuilding after kernel updates
- WiFi provides adequate performance for most services when ethernet driver unavailable
- Traefik reverse proxy eliminates need for individual service IP addresses