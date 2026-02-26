#!/bin/bash
# Script to generate a 1-day token for service account 'cd' and save to file

set -e

SA_NAME="cd"
NAMESPACE="homework"
TOKEN_FILE="token"
DURATION="24h"

echo "Generating token for service account $SA_NAME in namespace $NAMESPACE..."
echo "Duration: $DURATION"

kubectl create token $SA_NAME -n $NAMESPACE --duration=$DURATION > $TOKEN_FILE

echo "Token saved to: $TOKEN_FILE"
echo ""
echo "Token details (decoded JWT payload):"
cat $TOKEN_FILE | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -m json.tool 2>/dev/null || \
cat $TOKEN_FILE | cut -d'.' -f2 | base64 -D 2>/dev/null | python3 -m json.tool 2>/dev/null || \
echo "(Could not decode token payload)"
