# Certadel Agent for Linux

Automated ACME certificate issuance and installation for **HAProxy, Apache and
Tomcat** on any systemd distro (Ubuntu, Debian, RHEL, Rocky, Alma), with live
verification, rollback and a web console on `https://<host>:9443`. The package is
self-contained — no .NET runtime needs to be installed.

The agent's source (engine, plugins, console) lives in
[certadel-agent-core](https://github.com/Quantex-Secure/certadel-agent-core), included
here as the `core/` submodule. This repository holds the Linux packaging.

## Install

Download `acme-manager-linux-x64-<version>.tar.gz` from
[Releases](https://github.com/Quantex-Secure/certadel-agent-linux/releases), then:

```bash
tar -xzf acme-manager-linux-x64-<version>.tar.gz
cd acme-manager-linux-x64-<version>
sudo bash install.sh
```

This installs the agent to `/opt/acme-manager`, creates `/var/lib/acme-manager`,
installs and starts the `acme-manager` systemd service, and opens TCP 9443 in
ufw/firewalld (best effort).

Browse to `https://<host>:9443/` and sign in with a **local Linux account** (checked via
PAM) that belongs to `root`, `sudo`, `wheel` or `admin`. To delegate to another group,
set `"Auth": { "AllowedGroup": "certadmins" }` in `/opt/acme-manager/appsettings.json`
(membership is resolved with `id -Gn`, so SSSD/LDAP groups work).

## Manage

```bash
systemctl status acme-manager
journalctl -u acme-manager -f          # live logs
systemctl restart acme-manager
```

## What it does on Linux

- Issue and renew via HTTP-01 (webroot or self-hosted listener) or DNS-01 (Azure,
  Cloudflare, Route 53, Google Cloud DNS, Namecheap, script, manual).
- Install for **HAProxy** (combined PEM), **Apache** (fullchain + key) and **Tomcat**
  (PKCS#12 keystore), each with an editable reload command (RHEL users change
  `apache2` to `httpd`).
- Verify the new certificate is served on loopback after every renewal; if not,
  restore the previous files, reload, and fail the run.
- **Coverage report:** read `haproxy.cfg` `crt`/`crt-list` sources and flag any served
  certificate nothing is renewing — including ones another tool renewed but never
  deployed.
- **Import from acme.sh**, then hand off so acme.sh stops renewing those domains.

## Upgrade

Extract the new package and run `sudo bash install.sh` again — it stops the service,
replaces the binaries and restarts. Data in `/var/lib/acme-manager` is preserved.

## Uninstall

```bash
sudo bash uninstall.sh            # keeps your data
sudo bash uninstall.sh --purge    # also removes /var/lib/acme-manager
```

## Notes

- The service runs as **root** because it writes certificates into system locations and
  reloads services with `systemctl` — the same posture as certbot and acme.sh.
- Secrets are encrypted at rest with AES-GCM under `/var/lib/acme-manager/secrets.key`.
- `linux-arm64` builds work too: `pwsh packaging/build-linux.ps1 -Runtime linux-arm64`.

## Build from source

Requires PowerShell 7 and the .NET 10 SDK (works on Linux or Windows).

```bash
git clone --recurse-submodules https://github.com/Quantex-Secure/certadel-agent-linux
cd certadel-agent-linux
pwsh packaging/build-linux.ps1          # → artifacts/acme-manager-linux-x64-<version>.tar.gz
```

To build against a newer core, `git -C core pull origin main` and commit the submodule.

## Security

Report vulnerabilities privately via **Security → Report a vulnerability**. See
[core's SECURITY.md](https://github.com/Quantex-Secure/certadel-agent-core/blob/main/SECURITY.md).

## License

[AGPL-3.0](LICENSE). Copyright © Quantex Secure.
