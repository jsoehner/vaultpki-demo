#!/bin/bash
set -e

# ANSI Color Codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0;37m' # No Color
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}======================================================${NC}"
echo -e "${BLUE}${BOLD}       HashiCorp Vault PKI Demo Orchestrator          ${NC}"
echo -e "${BLUE}${BOLD}======================================================${NC}"

# Check for docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker is required but not installed.${NC}" >&2
    exit 1
fi

# Determine compose command
COMPOSE_CMD="docker compose"
if ! docker compose version &> /dev/null; then
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        echo -e "${RED}Error: docker compose plugin or docker-compose is required but not installed.${NC}" >&2
        exit 1
    fi
fi

# Determine and validate image registry prefix
if [ -z "${REGISTRY_PREFIX:-}" ]; then
    TRUSTED_PREFIX="oss.jsigroup.local:8080/"
    TRUSTED_IMAGE="${TRUSTED_PREFIX}hashicorp/vault:latest"
    if docker image inspect "$TRUSTED_IMAGE" &> /dev/null; then
        echo -e "${GREEN}Using locally cached images from trusted registry prefix: ${TRUSTED_PREFIX}${NC}"
        export REGISTRY_PREFIX="$TRUSTED_PREFIX"
    elif docker manifest inspect "$TRUSTED_IMAGE" &> /dev/null; then
        echo -e "${GREEN}Verified trusted registry: ${TRUSTED_PREFIX}${NC}"
        export REGISTRY_PREFIX="$TRUSTED_PREFIX"
    else
        echo -e "${YELLOW}[!] Note: Images not found on trusted registry 'oss.jsigroup.local:8080'.${NC}"
        echo -e "${YELLOW}    Gracefully falling back to Docker Hub upstream images.${NC}"
        export REGISTRY_PREFIX=""
    fi
fi

echo -e "${YELLOW}Stopping any existing containers and cleaning volumes...${NC}"
$COMPOSE_CMD down -v

# If no vault keys exist, clean leftover raft storage so Vault can initialize fresh
if [ ! -f "config/vault-keys.txt" ] && [ -d "data" ]; then
    rm -rf data/* certs/* agent/roleid agent/secretid 2>/dev/null || true
fi

echo -e "${YELLOW}Spinning up the Vault PKI stack...${NC}"
$COMPOSE_CMD up -d

echo -e "${YELLOW}Waiting for Vault initialization and PKI configuration...${NC}"
MAX_WAIT=30
WAIT_COUNT=0
INIT_SUCCESS=false

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    STATUS=$(docker inspect -f '{{.State.Status}}' vault-init 2>/dev/null || echo "not-found")
    
    if [ "$STATUS" = "exited" ]; then
        EXIT_CODE=$(docker inspect -f '{{.State.ExitCode}}' vault-init)
        if [ "$EXIT_CODE" -eq 0 ]; then
            INIT_SUCCESS=true
            break
        else
            echo -e "${RED}vault-init service failed with exit code $EXIT_CODE${NC}"
            echo -e "${YELLOW}Showing vault-init logs:${NC}"
            docker logs vault-init
            exit 1
        fi
    elif [ "$STATUS" = "not-found" ]; then
        echo -e "${RED}Error: vault-init container not found.${NC}"
        exit 1
    fi
    
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    echo -n "."
done
echo ""

if [ "$INIT_SUCCESS" = "false" ]; then
    echo -e "${RED}Error: Timeout waiting for vault-init to complete.${NC}"
    exit 1
fi

echo -e "${GREEN}Initialization complete!${NC}"
echo -e "${BLUE}Current container status:${NC}"
docker ps --filter name=vault- --filter name=demo-nginx --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n${GREEN}${BOLD}Demo stack is running and healthy!${NC}"
echo -e "${BLUE}Access the monitoring dashboard at: ${NC}${YELLOW}http://127.0.0.1:8080${NC}"
echo -e "${BLUE}Access secure NGINX endpoint at:    ${NC}${YELLOW}https://127.0.0.1:8443${NC}"
echo -e "${BLUE}Watch rotation logs with:          ${NC}${YELLOW}./watch-rotation.sh (or .\\watch-rotation.ps1)${NC}"
echo -e "${BLUE}Check generated certificate with:  ${NC}${YELLOW}./check-cert.sh (or .\\check-cert.ps1)${NC}"
echo -e "${BLUE}${BOLD}======================================================${NC}"
