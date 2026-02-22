#!/bin/bash

# 1. Generate WireGuard configuration from template
# This ensures secrets stored in .env are injected at runtime
echo "Generating WireGuard configuration..."
TEMPLATE="/templates/wg0.conf.template"
TARGET="/etc/wireguard/wg0.conf"

if [ -f "$TEMPLATE" ]; then
    # Use sed to replace placeholders.
    # We use | as delimiter to avoid issues with / in variables
    sed -e "s|\${WG_ADDRESS}|$WG_ADDRESS|g" \
        -e "s|\${WG_PRIVATE_KEY}|$WG_PRIVATE_KEY|g" \
        -e "s|\${WG_MTU}|$WG_MTU|g" \
        -e "s|\${WG_DNS}|$WG_DNS|g" \
        -e "s|\${WG_PEER_PUBLIC_KEY}|$WG_PEER_PUBLIC_KEY|g" \
        -e "s|\${WG_PEER_PRESHARED_KEY}|$WG_PEER_PRESHARED_KEY|g" \
        -e "s|\${WG_PEER_ENDPOINT}|$WG_PEER_ENDPOINT|g" \
        "$TEMPLATE" > "$TARGET"
    chmod 600 "$TARGET"
    echo "WireGuard config generated at $TARGET"
else
    echo "ERROR: WireGuard template not found at $TEMPLATE"
fi

# 2. Force WireGuard up
if ! ip addr show wg0 > /dev/null 2>&1; then
    echo "Applying WireGuard fix..."
    wg-quick up wg0
fi

# 3. Force the LAN route (so you don't get locked out)
# Dynamically detect the gateway if possible, fallback to 172.18.0.1
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
GATEWAY=${GATEWAY:-172.18.0.1}

echo "Applying Routing fix for LAN(s): $VPN_LAN_NETWORK via $GATEWAY"
IFS=',' read -ra SUBNETS <<< "$VPN_LAN_NETWORK"
for SUBNET in "${SUBNETS[@]}"; do
    # Trim whitespace just in case
    SUBNET=$(echo "$SUBNET" | xargs)
    if [ -n "$SUBNET" ]; then
        echo "Adding route for $SUBNET"
        ip route add "$SUBNET" via "$GATEWAY" dev eth0 || echo "Failed to add route for $SUBNET (may already exist)"
    fi
done

# 4. Setup MAM session update cron (every 10 minutes)
echo "Setting up MAM session cron..."
MAM_SCRIPT="/usr/local/bin/mam-update"
if [ -f "$MAM_SCRIPT" ]; then
    chmod +x "$MAM_SCRIPT"
    # Add to crontab if not already there
    if ! crontab -l 2>/dev/null | grep -q "mam-update"; then
        (crontab -l 2>/dev/null; echo "*/10 * * * * $MAM_SCRIPT >> /config/mam_config/mam.log 2>&1") | crontab -
        echo "Cron job added."
    fi
    # Start crond if not running
    pgrep crond > /dev/null || crond

    # Run once immediately in background
    echo "Running initial MAM update..."
    "$MAM_SCRIPT" >> /config/mam_config/mam.log 2>&1 &
else
    echo "Warning: MAM script not found at $MAM_SCRIPT"
fi

echo "Network fixes applied successfully."
