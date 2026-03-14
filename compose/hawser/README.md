# Hawser on Remote Hosts (Recommended: systemd service)

Based on current upstream docs/releases, the practical approach is:

- install Hawser binary via official install script
- run it as a systemd service on each host

This is better than running Hawser as a container in your non-Swarm setup because it starts on boot and is independent of your app stacks.

## 1) Install (on each remote host)

```bash
curl -fsSL https://raw.githubusercontent.com/Finsys/hawser/main/scripts/install.sh | bash
```

This installs:
- binary at `/usr/local/bin/hawser`
- config dir `/etc/hawser`
- `hawser.service`

## 2) Configure Standard mode (same LAN / reachable host)

Edit `/etc/hawser/config`:

```bash
DOCKER_SOCKET=/var/run/docker.sock
PORT=2376
TOKEN=<long-random-token>
# Optional:
# AGENT_NAME=<host-name>
# TLS_CERT=/etc/hawser/server.crt
# TLS_KEY=/etc/hawser/server.key
```

Start:

```bash
sudo systemctl enable --now hawser
sudo systemctl status hawser
```

## 3) Configure Edge mode (no inbound ports)

Edit `/etc/hawser/config`:

```bash
DOCKER_SOCKET=/var/run/docker.sock
DOCKHAND_SERVER_URL=wss://dockhand.tuxito.be/api/hawser/connect
TOKEN=<edge-token-generated-in-dockhand>
# Optional for self-signed Dockhand cert:
# CA_CERT=/etc/hawser/dockhand-ca.pem
```

Then:

```bash
sudo systemctl restart hawser
sudo systemctl status hawser
```

## 4) Validate

Standard mode health:

```bash
curl http://127.0.0.1:2376/_hawser/health
```

Logs:

```bash
sudo journalctl -u hawser -f
```

## Notes

- Latest checked release: `v0.2.37` (published 2026-03-11).
- Release assets are tarballs; no official apt package was found in latest assets.
- If hosts are directly reachable, Standard mode is simpler.
- If hosts are behind NAT/firewalls, Edge mode is preferred.

## Ansible automation

Ansible files were added under `ansible/hawser`:

- `ansible/hawser/playbook.yml`
- `ansible/hawser/inventory.yml`
- `ansible/hawser/vars/main.yml`
- `ansible/hawser/templates/*`

Run:

```bash
ansible-playbook -i ansible/hawser/inventory.yml ansible/hawser/playbook.yml
```

Override mode/token at runtime (example):

```bash
ansible-playbook -i ansible/hawser/inventory.yml ansible/hawser/playbook.yml \
  -e "hawser_mode=edge" \
  -e "hawser_token=REPLACE_ME" \
  -e "hawser_dockhand_server_url=wss://dockhand.tuxito.be/api/hawser/connect"
```
