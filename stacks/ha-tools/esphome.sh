#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ESPHome (bare-metal, no Docker) install for Debian/Ubuntu LXC
# - Installs ESPHome into a Python venv
# - Creates a dedicated user + working directory
# - Runs ESPHome dashboard via systemd on 0.0.0.0:6052
# - Designed to be reachable via Traefik at https://esphome.tuxito.be
#
# Usage:
#   sudo bash install-esphome-lxc.sh
#
# Notes for LXC:
# - If you need USB passthrough for flashing (ttyUSB*), you must allow it in Proxmox LXC config.
# - For OTA-only usage, no USB passthrough needed.
# ==============================================================================

ESPHOME_USER="esphome"
ESPHOME_HOME="/opt/esphome"
ESPHOME_VENV="${ESPHOME_HOME}/venv"
ESPHOME_PORT="6052"
ESPHOME_BIND="0.0.0.0"
ESPHOME_SERVICE="/etc/systemd/system/esphome.service"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run as root (sudo)."
    exit 1
  fi
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates curl git \
    python3 python3-venv python3-pip \
    build-essential pkg-config \
    libffi-dev libssl-dev \
    avahi-daemon
}

create_user_and_dirs() {
  if ! id -u "${ESPHOME_USER}" >/dev/null 2>&1; then
    useradd --system --create-home --home-dir "${ESPHOME_HOME}" --shell /usr/sbin/nologin "${ESPHOME_USER}"
  fi

  mkdir -p "${ESPHOME_HOME}/config"
  chown -R "${ESPHOME_USER}:${ESPHOME_USER}" "${ESPHOME_HOME}"
  chmod 750 "${ESPHOME_HOME}"
}

install_esphome_venv() {
  if [[ ! -d "${ESPHOME_VENV}" ]]; then
    python3 -m venv "${ESPHOME_VENV}"
  fi

  "${ESPHOME_VENV}/bin/python" -m pip install --upgrade pip setuptools wheel

  # Install ESPHome itself
  "${ESPHOME_VENV}/bin/pip" install --upgrade esphome

  chown -R "${ESPHOME_USER}:${ESPHOME_USER}" "${ESPHOME_VENV}"
}

create_systemd_service() {
  cat > "${ESPHOME_SERVICE}" <<EOF
[Unit]
Description=ESPHome Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${ESPHOME_USER}
Group=${ESPHOME_USER}
WorkingDirectory=${ESPHOME_HOME}/config
Environment=PATH=${ESPHOME_VENV}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=${ESPHOME_VENV}/bin/esphome dashboard ${ESPHOME_HOME}/config --address ${ESPHOME_BIND} --port ${ESPHOME_PORT}
Restart=on-failure
RestartSec=2
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=${ESPHOME_HOME}/config

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now esphome.service
}

print_status() {
  echo
  echo "ESPHome installed and running."
  echo " - Dashboard: http://$(hostname -I | awk '{print $1}'):${ESPHOME_PORT}"
  echo " - Config dir: ${ESPHOME_HOME}/config"
  echo
  echo "Service status:"
  systemctl --no-pager -l status esphome.service || true
  echo
  echo "Logs:"
  echo "  journalctl -u esphome.service -f"
  echo
  echo "Traefik upstream should point to: http://<LXC_IP>:${ESPHOME_PORT}"
  echo
}

main() {
  require_root
  install_packages
  create_user_and_dirs
  install_esphome_venv
  create_systemd_service
  print_status
}

main "$@"