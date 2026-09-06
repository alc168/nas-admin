#!/bin/bash

# --- User Configuration ---
MAMID="PUT-YOUR-MAM-ID-HERE"

BUFFER=10000             # Stay above 10000 points
VIP="1"                  # Set to 1 to enable VIP buying
WEDGEHOURS=0             # Buy a wedge every 4 hours (0 to disable)

# --- Ubuntu Server Paths ---
WORKDIR="${HOME}/.mam_script"
LOGFILE="${HOME}/scripts/activity.log"

# --- Initialization ---
mkdir -p "${WORKDIR}"
mkdir -p "$(dirname "$LOGFILE")"

POINTSURL='https://www.myanonamouse.net/json/bonusBuy.php/?spendtype=upload&amount='
VIPURL='https://www.myanonamouse.net/json/bonusBuy.php/?spendtype=VIP&duration=max&_='
WEDGEURL_BASE='https://www.myanonamouse.net/json/bonusBuy.php/?spendtype=wedges&source=points&_='

# --- Setup Logging ---
exec >> "${LOGFILE}" 2>&1  # Redirect all output to the log file

echo "--- Run started at $(date) ---"

# Native Linux millisecond timestamp
TIMESTAMP=$(date +%s%3N)
WEDGEURL="${WEDGEURL_BASE}${TIMESTAMP}"

cd "${WORKDIR}"

# Verify dependencies are available
for cmd in jq curl bc; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' is not installed. Run: sudo apt install $cmd"
        exit 1
    fi
done

MAMUID=$(curl -s -b "${WORKDIR}/MAM.cookies" -c "${WORKDIR}/MAM.cookies" "https://www.myanonamouse.net/jsonLoad.php?snatch_summary" | tee "${WORKDIR}/MAM.json" | jq .uid 2>/dev/null)

if [ -z "$MAMUID" ] || [ "$MAMUID" = "null" ]; then
    echo "Session invalid. Attempting to login with MAMID..."
    if [ -z "$MAMID" ]; then
        echo "Please update the MAMID in the script."
        exit 1
    fi

    MAMUID=$(curl -s -b "mam_id=${MAMID}" -c "${WORKDIR}/MAM.cookies" "https://www.myanonamouse.net/jsonLoad.php?snatch_summary" | tee "${WORKDIR}/MAM.json" | jq .uid 2>/dev/null)
    
    if [ -z "$MAMUID" ] || [ "$MAMUID" = "null" ]; then
        echo " => Cannot create new session! Check your MAMID."
        exit 1
    else
        echo " => New Session created (UID: $MAMUID)"
    fi
else
    echo " => Existing session valid (UID: $MAMUID)"
fi

# Collect current points
echo "Collecting current points..."
POINTS=$(curl -s -b "${WORKDIR}/MAM.cookies" -c "${WORKDIR}/MAM.cookies" "https://www.myanonamouse.net/jsonLoad.php?id=${MAMUID}" | jq '.seedbonus')

if [ -z "$POINTS" ] || [ "$POINTS" = "null" ]; then
    echo " => Failed to get bonus points - aborting."
    exit 1
else
    echo " => Current points: $POINTS"
fi

# Wedge logic
if [ "$WEDGEHOURS" -gt 0 ]; then
    WEDGEMINS=$(( WEDGEHOURS * 60 - 10 ))
    if ! find "${WORKDIR}/wedge.last" -mmin -${WEDGEMINS} 2>/dev/null | grep -q "wedge.last"; then
        echo "Need to buy a wedge!"
        if (( $(echo "$POINTS < 50000" | bc -l) )); then
            echo "Not enough points for wedge, skipping."
        else
            curl -s -b "${WORKDIR}/MAM.cookies" -c "${WORKDIR}/MAM.cookies" "$WEDGEURL"
            touch "${WORKDIR}/wedge.last"
            POINTS=$(curl -s -b "${WORKDIR}/MAM.cookies" -c "${WORKDIR}/MAM.cookies" "https://www.myanonamouse.net/jsonLoad.php?id=${MAMUID}" | jq '.seedbonus')
        fi
    fi
fi

# VIP logic
if [ -n "$VIP" ]; then
    VIPRESULT=$(curl -s -b "${WORKDIR}/MAM.cookies" -c "${WORKDIR}/MAM.cookies" "${VIPURL}${TIMESTAMP}" | jq .success 2>/dev/null)
    if [ "$VIPRESULT" != "true" ]; then
        echo "VIP purchase failed or not eligible."
    fi
fi

# Spending logic
for i in 100 50 ; do
    echo "Checking to spend ${i}GB..."
    UPLOADREQUIRED=$(( i * 500 + BUFFER ))
    
    while (( $(echo "$POINTS > $UPLOADREQUIRED" | bc -l) )); do
        echo "$POINTS is more than $UPLOADREQUIRED - buying ${i}GB of upload"
        
        RESPONSE=$(curl -s -b "${WORKDIR}/MAM.cookies" -c "${WORKDIR}/MAM.cookies" "${POINTSURL}${i}&_=${TIMESTAMP}")
        NEWPOINTS_RAW=$(echo "$RESPONSE" | jq '.seedbonus' 2>/dev/null)
        
        if [ -z "$NEWPOINTS_RAW" ] || [ "$NEWPOINTS_RAW" = "null" ]; then
            echo "Spend failed - Server returned: $RESPONSE"
            break 2
        fi

        NEWPOINTS_INT=$(echo "$NEWPOINTS_RAW" | sed -e 's/\..*$//')
        CURRENT_POINTS_INT=$(echo "$POINTS" | sed -e 's/\..*$//')

        if [ "$NEWPOINTS_INT" -lt "$CURRENT_POINTS_INT" ]; then
            POINTS=$NEWPOINTS_RAW
            echo "Success! New balance: $POINTS"
            sleep 1 
        else
            echo "Points did not decrease - purchase might have failed on server side."
            break 2
        fi
    done
done

echo "--- Run finished at $(date) ---"
