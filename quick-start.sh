#!/bin/bash

# HRM Labs MongoDB Quick Start Script
# Enhanced for auto Node.js/npm installation and dashboard setup

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════╗
║                    HRM Labs MongoDB Automation                       ║
║                         Quick Start Script                           ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

echo -e "${BLUE}🚀 Starting HRM Labs MongoDB Quick Setup...${NC}"

# Pre-flight checks
echo -e "${YELLOW}📋 Performing pre-flight checks...${NC}"

# Check if main script exists
if [ ! -f "./hrmlabs-mongo-automation.sh" ]; then
    echo -e "${RED}❌ Main automation script not found!${NC}"
    echo "Please ensure hrmlabs-mongo-automation.sh is in the current directory."
    exit 1
fi

# Check Node.js & npm
echo -e "${BLUE}🔍 Checking Node.js & npm...${NC}"
if ! command -v node &>/dev/null; then
    echo -e "${YELLOW}📦 Installing Node.js 20 LTS...${NC}"
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs
fi

echo -e "${GREEN}✓ Node.js version: $(node -v)${NC}"
echo -e "${GREEN}✓ npm version: $(npm -v)${NC}"

# Install dependencies
echo -e "${BLUE}📦 Installing npm dependencies...${NC}"
npm install

# Ensure .env exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠ .env file not found, creating from example...${NC}"
    cp .env.example .env
fi

# Check node connectivity
echo -e "${BLUE}🔍 Checking node connectivity...${NC}"
NODES=("hrmlabs-mongo-primary" "hrmlabs-mongo-secondary" "hrmlabs-mongo-analytics")
FAILED_NODES=()

for node in "${NODES[@]}"; do
    if ping -c 1 -W 3 "$node" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $node is reachable${NC}"
    else
        echo -e "${RED}❌ $node is not reachable${NC}"
        FAILED_NODES+=("$node")
    fi
done

if [ ${#FAILED_NODES[@]} -gt 0 ]; then
    echo -e "${RED}❌ Some nodes are not reachable. Please check:${NC}"
    for node in "${FAILED_NODES[@]}"; do
        echo -e "${RED}  - $node${NC}"
    done
    exit 1
fi

# SSH connectivity check
echo -e "${BLUE}🔐 Checking SSH connectivity...${NC}"
SSH_FAILED=()

for node in "${NODES[@]}"; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$node" "echo 'SSH OK'" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ SSH to $node is working${NC}"
    else
        echo -e "${YELLOW}⚠ SSH to $node failed${NC}"
        SSH_FAILED+=("$node")
    fi
done

if [ ${#SSH_FAILED[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ SSH connectivity issues detected.${NC}"
    echo "Would you like to:"
    echo "1. Continue with password authentication"
    echo "2. Setup SSH keys first"
    echo "3. Exit and fix manually"
    read -p "Choose option (1-3): " choice
    
    case $choice in
        1)
            echo -e "${BLUE}📝 Continuing with password authentication...${NC}"
            export SSH_PASSWORD_AUTH=true
            ;;
        2)
            echo -e "${BLUE}🔑 Setting up SSH keys...${NC}"
            if [ ! -f "/root/.ssh/id_rsa" ]; then
                ssh-keygen -t rsa -b 4096 -C "hrmlabs-automation" -f /root/.ssh/id_rsa -N ""
                echo -e "${GREEN}✓ SSH key generated${NC}"
            fi
            for node in "${SSH_FAILED[@]}"; do
                ssh-copy-id "root@$node" || echo -e "${YELLOW}⚠ Failed to copy key to $node${NC}"
            done
            ;;
        3)
            echo -e "${BLUE}👋 Exiting. Please fix SSH connectivity and try again.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option. Exiting.${NC}"
            exit 1
            ;;
    esac
fi

echo -e "${GREEN}✅ Pre-flight checks completed!${NC}"
echo ""

# Start main automation
echo -e "${GREEN}🚀 Starting main automation script...${NC}"
chmod +x ./hrmlabs-mongo-automation.sh
./hrmlabs-mongo-automation.sh

# Start web dashboard
echo -e "${BLUE}🌐 Starting Web Dashboard...${NC}"
npm run dev > dashboard.log 2>&1 &

# Success message
echo ""
echo -e "${GREEN}🎉 HRM Labs MongoDB Cluster Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}📊 Access your dashboard:${NC}"
echo "🌐 Web URL: http://localhost:3000"
echo "🌐 Alternative: http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo -e "${BLUE}🔧 Quick commands:${NC}"
echo "📊 Check replica status: mongosh --host hrmlabs-mongo-primary:27017 --eval 'rs.status()'"
echo "📋 View dashboard logs: tail -f ./dashboard.log"
echo "🔄 Restart dashboard: npm start"
echo ""
echo -e "${GREEN}✅ Your HRM Labs MongoDB cluster is ready for use!${NC}"
