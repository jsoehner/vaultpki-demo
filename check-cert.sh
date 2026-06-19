#!/bin/bash

# Default values if not provided
DOMAIN=${1:-test.example.com}
PORT=${2:-8443}
HOST=${3:-127.0.0.1}

echo "=================================================="
echo " Fetching Certificate for $DOMAIN on port $PORT"
echo "=================================================="
echo ""

# Use openssl s_client to fetch the certificate from the server and parse it with openssl x509
echo | openssl s_client -showcerts -connect "$HOST:$PORT" -servername "$DOMAIN" 2>/dev/null | openssl x509 -inform pem -noout -text -certopt no_pubkey,no_sigdump

echo ""
echo "=================================================="
echo " Done"
echo "=================================================="
