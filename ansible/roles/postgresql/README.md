# PostgreSQL Role - Docker/Remote Instance

## Overview

This role manages users and databases in an **existing** PostgreSQL instance (Docker, remote, or local). It does NOT install PostgreSQL.

Key features:
- Creates databases and users
- Retrieves passwords from Bitwarden at runtime
- Works with Docker Compose PostgreSQL containers
- Works with remote PostgreSQL servers
- Secure password handling with `no_log: true`

## How Bitwarden Lookup Works

### The Bitwarden Lookup Plugin

Your custom lookup plugin (`ansible/plugins/lookup/bitwarden.py`) works as follows:

1. **Session Token**: Reads `BW_SESSION` environment variable
2. **Search**: Runs `bw list items --search "<term>"` to find matching items
3. **Extract**: Retrieves the password field from the matched item
4. **Return**: Provides the password to Ansible for use

### Example Flow

```yaml
# In your vars/main.yml:
password: "{{ lookup('bitwarden', 'Nextcloud Database') }}"

# What happens:
# 1. Ansible calls the bitwarden lookup plugin
# 2. Plugin runs: bw list items --search "Nextcloud Database" --session $BW_SESSION
# 3. Plugin extracts the password from the JSON response
# 4. Password is used in the postgresql_user task
```

### Required Setup

Before running the playbook:

```bash
# 1. Unlock Bitwarden and export session
export BW_SESSION=$(bw unlock --raw)

# 2. Verify it works
bw list items --search "Nextcloud Database" --session $BW_SESSION

# 3. Run your playbook
ansible-playbook -i inventory site.yml
```

### Bitwarden Item Structure

Each database password should be stored in Bitwarden as:
- **Name**: "Nextcloud Database" (or whatever you use in lookup)
- **Type**: Login
- **Password**: The actual database password

The lookup plugin searches by name and retrieves the password field.

## Docker Compose Usage

### Example Docker Compose Setup

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: your_admin_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### Inventory Configuration

```yaml
# inventory/host_vars/postgresql.yml
postgresql_host: "localhost"  # or your Docker host IP
postgresql_port: 5432
postgresql_admin_user: "postgres"
postgresql_admin_password: "your_admin_password"  # Or from vault

postgresql_users:
  - name: nextcloud
    password: "{{ lookup('bitwarden', 'Nextcloud Database') }}"
    db: nextcloud
  - name: immich
    password: "{{ lookup('bitwarden', 'Immich Database') }}"
    db: immich
```

### Running Against Docker PostgreSQL

```bash
# 1. Ensure PostgreSQL container is running
docker compose up -d postgres

# 2. Unlock Bitwarden
export BW_SESSION=$(bw unlock --raw)

# 3. Run the role
ansible-playbook -i inventory site.yml --tags postgresql
```

## Variables

### Connection Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `postgresql_host` | `localhost` | PostgreSQL host (Docker host or remote IP) |
| `postgresql_port` | `5432` | PostgreSQL port |
| `postgresql_admin_user` | `postgres` | Admin user for creating databases/users |
| `postgresql_admin_password` | (required) | Admin password |
| `postgresql_wait_for_ready` | `true` | Wait for PostgreSQL to be ready |

### User Configuration

```yaml
postgresql_users:
  - name: myapp              # PostgreSQL username
    password: "{{ lookup('bitwarden', 'MyApp Database') }}"
    db: myapp                # Database to create and grant access
```

## Complete Example

### 1. Bitwarden Items

Create items in Bitwarden:
- Name: "Nextcloud Database", Password: "secure_nextcloud_pass"
- Name: "Immich Database", Password: "secure_immich_pass"

### 2. Inventory File

```yaml
# inventory/host_vars/docker_host.yml
postgresql_host: "192.168.1.100"  # Your Docker host
postgresql_port: 5432
postgresql_admin_user: "postgres"
postgresql_admin_password: "{{ lookup('bitwarden', 'PostgreSQL Admin') }}"

postgresql_users:
  - name: nextcloud
    password: "{{ lookup('bitwarden', 'Nextcloud Database') }}"
    db: nextcloud
  - name: immich
    password: "{{ lookup('bitwarden', 'Immich Database') }}"
    db: immich
```

### 3. Playbook

```yaml
# site.yml
---
- name: Configure PostgreSQL
  hosts: postgresql
  roles:
    - postgresql
```

### 4. Run

```bash
# Unlock Bitwarden
export BW_SESSION=$(bw unlock --raw)

# Run playbook
ansible-playbook -i inventory site.yml
```

## Security Notes

- ✅ Passwords never stored in plain text
- ✅ `no_log: true` prevents password exposure in logs
- ✅ Bitwarden session token is temporary
- ✅ All password tasks use secure connections

## Troubleshooting

### "BW_SESSION environment variable not set"
```bash
export BW_SESSION=$(bw unlock --raw)
```

### "No items found in Bitwarden matching 'X'"
Check the exact name in Bitwarden:
```bash
bw list items --search "Your Item Name" --session $BW_SESSION
```

### "Connection refused to PostgreSQL"
- Ensure Docker container is running: `docker ps`
- Check port binding: `docker compose port postgres 5432`
- Verify `postgresql_host` and `postgresql_port` in inventory

### "Authentication failed"
- Verify `postgresql_admin_password` is correct
- Check PostgreSQL logs: `docker compose logs postgres`

## File Structure

```
postgresql/
├── defaults/
│   └── main.yml          # Default connection settings
├── tasks/
│   ├── main.yml          # Wait for PostgreSQL readiness
│   └── users.yml         # User and database management
└── README.md             # This file
```

## Remote PostgreSQL

This role also works with remote PostgreSQL servers:

```yaml
# inventory/host_vars/remote_pg.yml
postgresql_host: "db.example.com"
postgresql_port: 5432
postgresql_admin_user: "postgres"
postgresql_admin_password: "{{ lookup('bitwarden', 'Remote PostgreSQL Admin') }}"
```

The role uses Ansible's PostgreSQL modules which connect remotely - no SSH required to the database server.