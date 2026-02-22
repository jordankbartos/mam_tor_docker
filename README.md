# qBittorrent Docker with WireGuard & MAM

A privacy-focused qBittorrent deployment optimized for Raspberry Pi (arm64), featuring automated WireGuard VPN integration and MyAnonamouse (MAM) session management.

## 🚀 Features
- **WireGuard Integration:** Automatically handles VPN connection on startup.
- **MAM Session Manager:** Keeps your MAM session active with automatic IP updates (runs every 10 minutes).
- **Secret Management:** Uses `.env` for all credentials - safe for GitHub.
- **Network Kill-switch:** Configured to leak-protect and bind qBittorrent to the VPN interface.

## 🛠 Setup

### 1. Prepare Environment
Copy the example environment file and fill in your details:
```bash
cp .env.example .env
nano .env
```
> **Note:** If you access your network via VPN (e.g., PiVPN/WireGuard), add your VPN client subnet to `LAN_NETWORK` (comma-separated, e.g., `192.168.1.0/24,10.6.0.0/24`) to ensure routing works correctly.

### 2. Configure qBittorrent (Optional)
If this is a fresh install, you can use the provided distribution config:
```bash
mkdir -p config/config
cp templates/qBittorrent.conf.dist config/config/qBittorrent.conf
```

### 3. Launch
```bash
docker compose up -d
```

### 4. Initial MAM Bootstrap
The MAM session must be initialized while the container is running to ensure the IP matches the session ID.
1. **Get the container's current VPN IP:**
   ```bash
   docker compose exec qbittorrent curl -s ip4.me/api/
   ```
2. **Generate MAM_ID:**
   - Go to myanonamouse.net > User Preferences > Security > Create Session.
   - Enter the IP from step 1.
   - Check **ASN-locked**.
   - Set **"Allow session to set dynamic seedbox"** to **Yes**.
   - Click "Create" to generate your `MAM_ID`.
3. **Initialize Session:**
   ```bash
   docker compose exec qbittorrent mam-update YOUR_MAM_ID
   ```
This will create a `MAM.cookie` file in your `config` folder. Subsequent updates (every 10 min) will happen automatically.

## 📜 Maintenance

### WireGuard Template
The `wg0.conf` is generated dynamically from `templates/wg0.conf.template` using variables in your `.env`. If you need to change your VPN provider details, edit the template or the `.env` file and restart the container.


### Dev Container
Open this folder in VS Code and use the Dev Container for a pre-configured environment with `shellcheck` and `pre-commit` hooks.

---
*Follows DRY, KISS, and Single Responsibility principles. See `AGENTS.md` for technical guidelines.*
