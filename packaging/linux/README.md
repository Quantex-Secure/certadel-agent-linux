# Certadel Agent — Linux

Automated TLS certificate management (ACME) with a web console on **https://&lt;host&gt;:9443**.
This package is self-contained — **no .NET runtime needs to be installed**. Works on any
systemd-based distro (tested target: Ubuntu and RHEL/Rocky/Alma).

## Install

```bash
tar -xzf acme-manager-linux-x64-<version>.tar.gz
cd acme-manager-linux-x64-<version>
sudo bash install.sh
```

This copies the agent to `/opt/acme-manager`, creates the data directory
`/var/lib/acme-manager`, installs and starts the `acme-manager` systemd service, and
opens TCP 9443 (ufw/firewalld, best effort).

Then browse to `https://<host>:9443/`. The console serves a self-signed cert until you
issue a real one for this host. **Log in with a local Linux user account** (verified via PAM).

## Manage

```bash
systemctl status acme-manager
journalctl -u acme-manager -f          # live logs
systemctl restart acme-manager
```

## What it can do on Linux

- Issue/renew certs via HTTP-01 (filesystem or self-hosted) or DNS-01 (Azure, Cloudflare, Route 53, Google Cloud DNS, Namecheap, script, manual).
- Install certs for **HAProxy** (combined PEM), **Apache** (fullchain + key), and **Tomcat**
  (PKCS#12 keystore), each with an editable reload command (e.g. `systemctl reload haproxy`;
  RHEL Apache users change `apache2` to `httpd`).

## Upgrade

Extract the new package and run `sudo bash install.sh` again — it stops the service, replaces
the binaries, and restarts. Your data in `/var/lib/acme-manager` is preserved.

## Uninstall

```bash
sudo bash uninstall.sh            # keeps your data
sudo bash uninstall.sh --purge    # also removes /var/lib/acme-manager
```

## Notes

- The service runs as **root** because it writes certs into system locations and reloads
  services via `systemctl` — the same posture as certbot/acme.sh.
- Runs on the standard port **9443** (same as the Windows agent).
