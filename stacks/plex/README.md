```markdown
# Intel Arc GPU Passthrough for Plex in Docker Swarm

This guide documents the setup of Intel Arc GPU passthrough from Proxmox to a Docker Swarm worker VM for hardware transcoding in Plex.

## Hardware Setup

- **Host**: Proxmox VE on Beelink NUC with Intel Arc Graphics (Meteor Lake-P)
- **GPU**: Intel Corporation Meteor Lake-P [Intel Arc Graphics] [8086:7d55]
- **VM**: swarm-worker-w1 (VM ID 1201)
- **Node ID**: m6n99yi7ltmxplvpni79dstx4

## Proxmox Host Configuration

### 1. Identify the GPU

```bash
lspci -nn | grep -i vga
# Output: 00:02.0 VGA compatible controller [0300]: Intel Corporation Meteor Lake-P [Intel Arc Graphics] [8086:7d55] (rev 08)
```

### 2. Configure VM for GPU Passthrough

The VM requires Q35 machine type for PCIe passthrough:

```bash
# Set machine type to Q35
qm set 1201 -machine q35

# Add GPU passthrough
qm set 1201 -hostpci0 00:02.0,pcie=1,rombar=0
```

### 3. Final VM Configuration

Key sections in `/etc/pve/nodes/proxmox-1/qemu-server/1201.conf`:

```
machine: q35
hostpci0: 00:02.0,pcie=1,rombar=0
```

### 4. Start the VM

```bash
qm start 1201
```

Expected output:
```
WARN: iothread is only valid with virtio disk or virtio-scsi-single controller, ignoring
kvm: -device vfio-pci,host=0000:00:02.0,id=hostpci0,bus=ich9-pcie-port-1,addr=0x0,rombar=0: info: OpRegion detected on Intel display 7d55.
```

The OpRegion message confirms successful GPU detection.

## VM Guest Configuration (Debian)

### 1. Install Standard Kernel

The cloud kernel lacks GPU drivers. Install the standard kernel:

```bash
sudo apt update
sudo apt install -y linux-image-amd64 linux-headers-amd64 firmware-linux-nonfree
```

### 2. Set GRUB to Boot Standard Kernel

Edit `/etc/default/grub`:

```bash
sudo nano /etc/default/grub
```

Change:
```
GRUB_DEFAULT="gnulinux-advanced-5b649c2a-d9a0-447d-a288-a1ac9a819502>gnulinux-6.12.57+deb13-amd64-advanced-5b649c2a-d9a0-447d-a288-a1ac9a819502"
```

Update GRUB and reboot:
```bash
sudo update-grub
sudo reboot
```

### 3. Verify GPU Access

After reboot:

```bash
# Check kernel
uname -r
# Should show: 6.12.57+deb13-amd64 (not cloud)

# Verify GPU is present
lspci | grep -i vga
# Should show both VGA devices including Intel Arc

# Check DRI devices
ls -la /dev/dri
# Should show: card0, card1, renderD128

# Verify i915 module
lsmod | grep i915
```

### 4. Configure Docker Access

```bash
# Add users to render and video groups
sudo usermod -aG render,video $USER
sudo usermod -aG render,video root

# Restart Docker
sudo systemctl restart docker

# Test Docker GPU access
docker run --rm --device=/dev/dri:/dev/dri ubuntu:22.04 ls -la /dev/dri
```

## Plex Docker Swarm Configuration

### Docker Compose File

Create `plex-compose.yml`:

```yaml
version: '3.8'

networks:
  traefik_public:
    external: true

services:
  plex:
    image: lscr.io/linuxserver/plex:latest
    restart: unless-stopped
    hostname: plex
    networks:
      - traefik_public
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Brussels
      - VERSION=docker
    volumes:
      - /mnt/proxmox_swarm_data/plex/config:/config
      - /mnt/proxmox_swarm_data/plex/transcode:/transcode
      - /path/to/your/media:/media
    devices:
      - /dev/dri:/dev/dri  # Intel Arc GPU passthrough
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.id == m6n99yi7ltmxplvpni79dstx4  # Pin to worker with GPU
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      labels:
        - "homepage.group=Media"
        - "homepage.name=Plex"
        - "homepage.icon=plex.png"
        - "homepage.href=https://plex.tuxito.be"
        - "homepage.description=Media Server"
        - "traefik.enable=true"
        - "traefik.http.routers.plex.rule=Host(`plex.tuxito.be`)"
        - "traefik.http.routers.plex.entrypoints=websecure"
        - "traefik.http.routers.plex.tls.certresolver=letsencrypt"
        - "traefik.http.services.plex.loadbalancer.server.port=32400"
        - "traefik.swarm.network=traefik_public"
```

### Deploy

```bash
docker stack deploy -c plex-compose.yml plex
```

### Verify Hardware Transcoding

1. Access Plex at `https://plex.tuxito.be`
2. Go to Settings → Transcoder
3. Verify "Use hardware acceleration when available" is enabled
4. Hardware device should show Intel Arc Graphics

## Troubleshooting

### GPU Not Showing in VM

```bash
# On Proxmox host
lspci -nn | grep -i vga

# Verify VM config
cat /etc/pve/nodes/proxmox-1/qemu-server/1201.conf | grep -E "machine|hostpci"
```

### No /dev/dri Devices

```bash
# Check kernel version (must be standard, not cloud)
uname -r

# Check if i915 loaded
lsmod | grep i915

# Manually load if needed
sudo modprobe i915
```

### Docker Can't Access GPU

```bash
# Verify groups
groups

# Should include: render, video

# Restart Docker service
sudo systemctl restart docker
```

## References

- VM Node: swarm-worker-w1
- VM ID: 1201
- Swarm Node ID: m6n99yi7ltmxplvpni79dstx4
- GPU PCI Address: 00:02.0
- Domain: tuxito.be
```