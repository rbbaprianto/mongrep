#!/bin/bash

# Setup GitHub Branch Script for HRM Labs
# This script creates and pushes the hrmlabs-replication branch

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up GitHub branch: hrmlabs-replication${NC}"

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
fi

# Add all files
echo "Adding files to git..."
git add .

# Commit changes
echo "Committing changes..."
git commit -m "feat: HRM Labs MongoDB Replication Automation

- Complete automation script for MongoDB cluster setup
- Web dashboard with real-time monitoring
- Dummy HR data generation with file attachments
- Live replication status, logs, and SSH console
- Configuration management system
- Production-ready MongoDB replication cluster

Features:
✅ MongoDB installation on Rocky Linux 9
✅ 3-node replication cluster (primary, secondary, analytics)
✅ Complete HR dummy data (employees, payroll, attendance, etc.)
✅ File attachments (PNG/JPG) for employee photos and contracts
✅ Modern responsive web dashboard
✅ Real-time replication monitoring
✅ Live log viewing from all nodes
✅ MongoDB query interface
✅ SSH console integration
✅ Configuration management with accounts.json
✅ Validation and health checks"

# Create and switch to hrmlabs-replication branch
echo "Creating branch: hrmlabs-replication..."
git checkout -b hrmlabs-replication

# Show current status
echo -e "${GREEN}✓ Branch 'hrmlabs-replication' created successfully!${NC}"
echo -e "${GREEN}✓ All files committed and ready for push${NC}"

echo ""
echo "To push to remote repository:"
echo "git remote add origin <your-repo-url>"
echo "git push -u origin hrmlabs-replication"

echo ""
echo -e "${BLUE}Branch setup completed!${NC}"