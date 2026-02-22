#!/bin/sh
# MAM Session Management Script
# Updates MAM with current VPN IP address

STATEDIR="/config/mam_config"
CACHEFILE="${STATEDIR}/MAM.ip"
COOKIEFILE="${STATEDIR}/MAM.cookie"

# Ensure directory exists
mkdir -p "$STATEDIR"

# 1. Determine the MAM ID to use
# Order of preference: 1) Command line argument ($1), 2) Environment variable ($MAM_ID)
MAM_ID_TO_USE="${1:-$MAM_ID}"

# 2. Get Current IP hash
# Using ip4.me/api/ to get plain IP
CURRENT_IP=$(curl -s ip4.me/api/)
NEWIP_HASH=$(echo "$CURRENT_IP" | md5sum | awk '{print $1}')

if [ -z "$CURRENT_IP" ]; then
    echo "$(date): ERROR - Could not retrieve current IP."
    exit 1
fi

OLDIP_HASH=$(cat "$CACHEFILE" 2>/dev/null)

# 3. Handle Bootstrapping
if [ ! -f "$COOKIEFILE" ] && [ -z "$MAM_ID_TO_USE" ]; then
    echo "$(date): MAM Session not initialized."
    echo "----------------------------------------------------------------------"
    echo "BOOTSTRAP REQUIRED:"
    echo "1. Current VPN IP: $CURRENT_IP"
    echo "2. Go to MAM > Profiles > Security and generate a MAM_ID for this IP."
    echo "3. Run: docker compose exec qbittorrent /config/mam_config/mam_session_id.sh YOUR_MAM_ID"
    echo "----------------------------------------------------------------------"
    exit 0
fi

# 4. Check for IP change or forced bootstrap
if [ "$OLDIP_HASH" != "$NEWIP_HASH" ] || [ -n "$1" ]; then
    echo "$(date): Change detected, first run, or forced update. Updating MAM..."

    # Detect first run (or forced arg) vs repeat run
    if [ ! -f "$COOKIEFILE" ] || [ -n "$1" ]; then
        echo "Initializing/Resetting cookies with MAM ID"
        RESPONSE=$(curl -s -b "mam_id=$MAM_ID_TO_USE" --cookie-jar "$COOKIEFILE" https://t.myanonamouse.net/json/dynamicSeedbox.php)
    else
        echo "Refreshing session with existing cookie file"
        RESPONSE=$(curl -s -b "$COOKIEFILE" --cookie-jar "$COOKIEFILE" https://t.myanonamouse.net/json/dynamicSeedbox.php)
    fi

    # Check for success and update cache
    if echo "$RESPONSE" | grep -q '"Success":true'; then
        echo "$NEWIP_HASH" > "$CACHEFILE"
        echo "$(date): Update successful. Response: $RESPONSE"
    else
        echo "$(date): Update failed. Response: $RESPONSE"
        # If we tried to use a cookie and failed, maybe the cookie is stale?
        # We don't delete it automatically to avoid loops, but we log the failure.
    fi
else
    echo "$(date): IP unchanged ($CURRENT_IP). No update needed."
fi

#
#

MAMID="8fLNm5Dw7daPlBaYuNXydM2XQoriRJ3whEPiCgFwbboRdGGQ_-OF_3Qr5YiryW_z5weWHCKYHXEkES_ShSV30CfrC6me_uizfueuRPUR9zyaboXa_h5InHPfDoN9h7BMp5-trr01yJ7D6GLT-UIDpt-uN5q9bVmA742wt52LekKzvxE33oZdB4-NK2VNPviVpkFgTuFUDWfJ0Vh7Odx2BqciJ2gHt9YgyBRzBTHvOdHlDqJgc8ZevhQCILqLdGXRArIZf3FhflPz8Q-Ki_EF0BjVMoKthmUglcxn"
STATEDIR="/config/mam_config"
CACHEFILE="${STATEDIR}/MAM.ip"
COOKIEFILE="${STATEDIR}/MAM.cookie"

# Ensure directory exists
mkdir -p "$STATEDIR"

# Get Current IP hash
NEWIP=$(curl ip4.me/api/ | md5sum | awk '{print $1}')
OLDIP=$(cat "$CACHEFILE" 2>/dev/null)

if [ "$OLDIP" != "$NEWIP" ]; then
    echo "Change detected or first run. Updating MAM..."

    # Detect first run vs repeat run based on Cookie file existence
    if [ ! -f "$COOKIEFILE" ]; then
        echo "First run: Initializing cookies with MAMID"
        RESPONSE=$(curl -b "mam_id=$MAMID" --cookie-jar "$COOKIEFILE" https://t.myanonamouse.net/json/dynamicSeedbox.php)
    else
        echo "Repeat run: Using existing cookie file"
        RESPONSE=$(curl -b "$COOKIEFILE" --cookie-jar "$COOKIEFILE" https://t.myanonamouse.net/json/dynamicSeedbox.php)
    fi

    # Display the result for visibility
    echo "MAM Response: $RESPONSE"

    # Check for success and update cache
    if echo "$RESPONSE" | grep -q '"Success":true'; then
        echo "$NEWIP" > "$CACHEFILE"
        echo "Update successful."
    else
        echo "Update failed."
    fi
fi
