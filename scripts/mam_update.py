#!/usr/bin/env python3
import sys
import os
import urllib.request
import urllib.parse
import http.cookiejar
import hashlib
import json
import logging
from datetime import datetime

# Configuration
STATEDIR = "/config/mam_config"
CACHE_FILE = os.path.join(STATEDIR, "MAM.ip")
COOKIE_FILE = os.path.join(STATEDIR, "MAM.cookie")
MAM_ID_ENV = os.environ.get("MAM_ID", "")
URL_IP_API = "http://ip4.me/api/"
URL_MAM_API = "https://t.myanonamouse.net/json/dynamicSeedbox.php"

# Setup logging
LOG_FILE = os.path.join(STATEDIR, "mam.log")

# Get root logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 1. File Handler (Detailed with timestamps)
file_formatter = logging.Formatter('%(asctime)s: %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
file_handler = logging.FileHandler(LOG_FILE)
file_handler.setFormatter(file_formatter)
logger.addHandler(file_handler)

# 2. Console Handler (Clean, message only)
console_formatter = logging.Formatter('%(message)s')
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setFormatter(console_formatter)
logger.addHandler(console_handler)

def get_current_ip():
    try:
        req = urllib.request.Request(
            URL_IP_API,
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.read().decode('utf-8').strip()
    except Exception as e:
        logging.error(f"Could not retrieve current IP: {e}")
        sys.exit(1)

def main():
    # Ensure directory exists
    if not os.path.exists(STATEDIR):
        os.makedirs(STATEDIR, exist_ok=True)

    # 1. Get Arguments
    # First argument is optional MAM_ID override
    mam_id_arg = sys.argv[1] if len(sys.argv) > 1 else ""
    mam_id_to_use = mam_id_arg if mam_id_arg else MAM_ID_ENV

    # 2. Get Current IP
    current_ip = get_current_ip()
    new_ip_hash = hashlib.md5(current_ip.encode()).hexdigest()

    # 3. Bootstrap Check
    # If no cookie exists AND no ID provided, we can't do anything.
    if not os.path.exists(COOKIE_FILE) and not mam_id_to_use:
        logging.info("MAM Session not initialized.")
        logging.info("-" * 70)
        logging.info("BOOTSTRAP REQUIRED:")
        logging.info(f"1. Current VPN IP: {current_ip}")
        logging.info("2. Go to myanonamouse.net > User Preferences > Security > Create Session")
        logging.info(f"3. Enter IP: {current_ip}")
        logging.info("4. Check 'ASN-locked' and set 'Allow session to set dynamic seedbox' to 'Yes'")
        logging.info("5. Click 'Create' and copy the generated Session ID.")
        logging.info("6. Run: docker compose exec qbittorrent mam-update YOUR_MAM_ID")
        logging.info("-" * 70)
        sys.exit(0)

    # 4. Check for IP Change (unless forced via arg)
    force_update = bool(mam_id_arg)
    old_ip_hash = ""
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, 'r') as f:
            old_ip_hash = f.read().strip()

    if (old_ip_hash == new_ip_hash) and not force_update:
        logging.info(f"IP unchanged ({current_ip}). No update needed.")
        sys.exit(0)

    logging.info("Change detected, first run, or forced update. Updating MAM...")

    # 5. Prepare Cookie Jar
    jar = http.cookiejar.MozillaCookieJar(COOKIE_FILE)

    # IS_BOOTSTRAP logic:
    # We are bootstrapping if this is a forced update OR if no cookie file exists.
    is_bootstrap = False

    if not os.path.exists(COOKIE_FILE) or force_update:
        is_bootstrap = True
        logging.info("Initializing/Resetting cookies with MAM ID")
        # Start fresh: clear any existing jar in memory if we are forcing an ID
        # (Though usually if forcing, we just overwrite)
    else:
        try:
            jar.load(ignore_discard=True, ignore_expires=True)
            logging.info("Refreshing session with existing cookie file")
        except Exception as e:
            logging.warning(f"Failed to load cookies, treating as bootstrap: {e}")
            is_bootstrap = True

    # 6. Prepare Request
    # If bootstrapping, we must inject the MAM ID into the cookie manually for the first request
    if is_bootstrap:
        # Create a cookie object for mam_id
        cookie = http.cookiejar.Cookie(
            version=0, name='mam_id', value=mam_id_to_use,
            port=None, port_specified=False,
            domain='.myanonamouse.net', domain_specified=True, domain_initial_dot=True,
            path='/', path_specified=True,
            secure=True, expires=None, discard=True,
            comment=None, comment_url=None, rest={'HttpOnly': ''}, rfc2109=False
        )
        jar.set_cookie(cookie)

    # 7. Execute Request
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    req = urllib.request.Request(URL_MAM_API, headers={'User-Agent': 'Mozilla/5.0'})

    try:
        with opener.open(req, timeout=30) as response:
            raw_data = response.read().decode('utf-8')

            try:
                data = json.loads(raw_data)
            except json.JSONDecodeError:
                logging.error(f"Failed to parse JSON response: {raw_data}")
                sys.exit(1)

            if data.get("Success") is True:
                # Save cookies to file
                jar.save(ignore_discard=True, ignore_expires=True)

                # Update IP Cache
                with open(CACHE_FILE, 'w') as f:
                    f.write(new_ip_hash)

                logging.info(f"Update successful. Response: {raw_data}")

            else:
                logging.error(f"Update failed. Response: {raw_data}")

                # 8. CLEANUP LOGIC (The Fix)
                # If this was a bootstrap attempt (initial or manual force) and it failed,
                # delete the cookie file to prevent an infinite error loop.
                if is_bootstrap:
                    logging.info("Bootstrap failed. Removing invalid cookie file to prevent loop.")
                    if os.path.exists(COOKIE_FILE):
                        os.remove(COOKIE_FILE)

    except Exception as e:
        logging.error(f"Network error during update: {e}")
        # If network fails during bootstrap, also cleanup to be safe?
        # Maybe safer to leave it if it's just a network blip,
        # but for bootstrap usually you want a clean retry.
        if is_bootstrap:
             logging.info("Bootstrap network error. Removing invalid cookie file.")
             if os.path.exists(COOKIE_FILE):
                os.remove(COOKIE_FILE)
        sys.exit(1)

if __name__ == "__main__":
    main()
