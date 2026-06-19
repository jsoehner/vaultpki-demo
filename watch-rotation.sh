#!/bin/bash

# Default values if not provided
DOMAIN=${1:-test.example.com}
PORT=${2:-8443}
HOST=${3:-127.0.0.1}

echo "=================================================="
echo " Watching Certificate for $DOMAIN on port $PORT"
echo " Certificates are configured to have a TTL of 1m."
echo " Vault Agent should rotate them approximately every 40s."
echo "=================================================="
echo ""

PREV_SERIAL=""

while true; do
    # Fetch cert from NGINX
    CERT_OUTPUT=$(echo | openssl s_client -showcerts -connect "$HOST:$PORT" -servername "$DOMAIN" 2>/dev/null | openssl x509 -inform pem -noout -text 2>/dev/null)
    
    if [ -z "$CERT_OUTPUT" ]; then
        echo "$(date '+%H:%M:%S') - Could not connect to $HOST:$PORT"
        sleep 5
        continue
    fi

    SERIAL=$(echo "$CERT_OUTPUT" | grep -A 1 "Serial Number:" | tail -n 1 | tr -d '[:space:]')
    NOT_AFTER=$(echo "$CERT_OUTPUT" | grep "Not After :" | sed -e 's/^[ \t]*//')

    if [ "$SERIAL" != "$PREV_SERIAL" ]; then
        echo "--------------------------------------------------"
        echo "🔄 CERTIFICATE ROTATED at $(date '+%H:%M:%S')"
        echo "   New Serial:   $SERIAL"
        echo "   $NOT_AFTER"
        echo "--------------------------------------------------"
        PREV_SERIAL=$SERIAL
    else
        echo "$(date '+%H:%M:%S') - Serial: $SERIAL (No change)"
    fi

    sleep 5
done
