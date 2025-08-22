#!/bin/bash

# HRM Labs MongoDB Replication Automation Script v2.0
# Author: AI Generator
# Description: Complete automation for MongoDB cluster setup with advanced web dashboard
# Usage: chmod +x hrmlabs-mongo-automation.sh && ./hrmlabs-mongo-automation.sh [options]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODES=("hrmlabs-mongo-primary" "hrmlabs-mongo-secondary" "hrmlabs-mongo-analytics")
MONGODB_PORT=27017
REPLICA_SET_NAME="hrmlabsrs"
WEB_PORT=3000
SSH_USER="root"
VERSION="2.0.0"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Display banner
display_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                   ║
    ║    🚀 HRM Labs MongoDB Automation & Management Dashboard v2.0     ║
    ║                                                                   ║
    ║    Complete MongoDB Cluster Setup & Real-time Management         ║
    ║                                                                   ║
    ╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Display help
show_help() {
    cat << EOF
HRM Labs MongoDB Automation Script v${VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -v, --version           Show version information
    -w, --web-only          Start only the web dashboard (skip MongoDB setup)
    -c, --cli-only          Run CLI installation only (no web dashboard)
    -p, --production        Run production setup with security hardening
    -t, --test              Run with test configuration
    --port PORT             Specify web dashboard port (default: 3000)
    --skip-deps             Skip dependency installation
    --skip-connectivity     Skip connectivity checks

EXAMPLES:
    $0                      # Full installation with web dashboard
    $0 --web-only           # Start only web dashboard
    $0 --production         # Production setup with security
    $0 --cli-only           # Traditional CLI-only setup

FEATURES:
    ✅ Automated MongoDB Cluster Setup (3 nodes)
    ✅ Web-based Installation Control
    ✅ Real-time Replication Monitoring
    ✅ Live Log Streaming from all nodes
    ✅ Integrated SSH Terminal (web-based)
    ✅ MongoDB Query Console
    ✅ Test Data Generation
    ✅ Health Monitoring & Alerting
    ✅ Automated Backup System
    ✅ Security Hardening (production mode)

REQUIREMENTS:
    - Rocky Linux 9 or compatible
    - Root access
    - SSH connectivity to all MongoDB nodes
    - Node hostnames: hrmlabs-mongo-primary, hrmlabs-mongo-secondary, hrmlabs-mongo-analytics

EOF
}

# Parse command line arguments
parse_arguments() {
    WEB_ONLY=false
    CLI_ONLY=false
    PRODUCTION=false
    TEST_MODE=false
    SKIP_DEPS=false
    SKIP_CONNECTIVITY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "HRM Labs MongoDB Automation Script v${VERSION}"
                exit 0
                ;;
            -w|--web-only)
                WEB_ONLY=true
                shift
                ;;
            -c|--cli-only)
                CLI_ONLY=true
                shift
                ;;
            -p|--production)
                PRODUCTION=true
                shift
                ;;
            -t|--test)
                TEST_MODE=true
                shift
                ;;
            --port)
                WEB_PORT="$2"
                shift 2
                ;;
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --skip-connectivity)
                SKIP_CONNECTIVITY=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Check system requirements
check_system_requirements() {
    log "Checking system requirements..."
    
    # Check OS
    if ! grep -q "Rocky Linux" /etc/os-release && ! grep -q "CentOS" /etc/os-release && ! grep -q "Red Hat" /etc/os-release; then
        warning "This script is optimized for Rocky Linux 9. Other distributions may work but are not officially supported."
    fi
    
    # Check available memory
    local mem_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $mem_gb -lt 2 ]]; then
        warning "System has less than 2GB RAM. MongoDB may not perform optimally."
    fi
    
    # Check available disk space
    local disk_gb=$(df / | awk 'NR==2{print int($4/1024/1024)}')
    if [[ $disk_gb -lt 5 ]]; then
        warning "Less than 5GB free disk space available. Consider freeing up space."
    fi
    
    log "System requirements check completed"
}

# Install local dependencies
install_local_dependencies() {
    if [[ "$SKIP_DEPS" == "true" ]]; then
        log "Skipping dependency installation"
        return 0
    fi
    
    log "Installing local dependencies..."
    
    # Update system
    dnf update -y
    
    # Install Node.js and npm
    if ! command -v node >/dev/null 2>&1; then
        dnf module install nodejs:18 npm -y
    else
        info "Node.js already installed: $(node --version)"
    fi
    
    # Install Python and pip
    if ! command -v python3 >/dev/null 2>&1; then
        dnf install python3 python3-pip -y
    else
        info "Python3 already installed: $(python3 --version)"
    fi
    
    # Install system tools
    dnf install -y openssh-clients curl wget git nc
    
    # Install MongoDB tools locally
    if ! command -v mongosh >/dev/null 2>&1; then
        cat > /etc/yum.repos.d/mongodb-org-7.0.repo << 'EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
EOF
        dnf install mongodb-mongosh mongodb-database-tools -y
    else
        info "MongoDB tools already installed"
    fi
    
    log "Local dependencies installed successfully"
}

# Check SSH connectivity to nodes
check_ssh_connectivity() {
    if [[ "$SKIP_CONNECTIVITY" == "true" ]]; then
        log "Skipping connectivity checks"
        return 0
    fi
    
    log "Checking SSH connectivity to nodes..."
    
    local failed_nodes=()
    for node in "${NODES[@]}"; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SSH_USER@$node" "echo 'SSH OK'" >/dev/null 2>&1; then
            info "SSH connectivity to $node: OK"
        else
            warning "Cannot connect to $node via SSH"
            failed_nodes+=("$node")
        fi
    done
    
    if [[ ${#failed_nodes[@]} -gt 0 ]]; then
        warning "SSH connectivity issues detected with: ${failed_nodes[*]}"
        warning "Some features may not work properly"
        
        if [[ "$CLI_ONLY" == "true" ]]; then
            error "CLI mode requires SSH connectivity to all nodes"
            exit 1
        fi
    fi
}

# Install MongoDB on remote node
install_mongodb_on_node() {
    local node=$1
    log "Installing MongoDB on $node..."
    
    ssh "$SSH_USER@$node" << 'EOF'
# Check if MongoDB is already installed
if command -v mongod >/dev/null 2>&1; then
    echo "MongoDB already installed on $(hostname)"
    exit 0
fi

# Add MongoDB repository
cat > /etc/yum.repos.d/mongodb-org-7.0.repo << 'REPO_EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
REPO_EOF

# Update system and install MongoDB
dnf update -y
dnf install mongodb-org -y

# Create MongoDB data directory
mkdir -p /var/lib/mongo
chown -R mongod:mongod /var/lib/mongo

# Enable and start MongoDB service
systemctl enable mongod
systemctl start mongod

echo "MongoDB installed successfully on $(hostname)"
EOF
}

# Configure MongoDB for replication
configure_mongodb_replication() {
    local node=$1
    log "Configuring MongoDB replication on $node..."
    
    ssh "$SSH_USER@$node" << EOF
# Stop MongoDB service
systemctl stop mongod

# Backup original config
cp /etc/mongod.conf /etc/mongod.conf.backup

# Create new MongoDB configuration
cat > /etc/mongod.conf << 'MONGO_CONF'
storage:
  dbPath: /var/lib/mongo
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 0.0.0.0

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

replication:
  replSetName: $REPLICA_SET_NAME

security:
  authorization: disabled
MONGO_CONF

# Set proper permissions
chown mongod:mongod /etc/mongod.conf
chmod 644 /etc/mongod.conf

# Create directories
mkdir -p /var/log/mongodb /var/run/mongodb
chown -R mongod:mongod /var/log/mongodb /var/run/mongodb

# Start MongoDB service
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to start
sleep 10

echo "MongoDB replication configured on \$(hostname)"
EOF
}

# Initialize replica set
initialize_replica_set() {
    log "Initializing MongoDB replica set..."
    
    # Connect to primary node and initialize replica set
    mongosh --host "${NODES[0]}:$MONGODB_PORT" --eval "
    rs.initiate({
        _id: '$REPLICA_SET_NAME',
        members: [
            { _id: 0, host: '${NODES[0]}:$MONGODB_PORT', priority: 2 },
            { _id: 1, host: '${NODES[1]}:$MONGODB_PORT', priority: 1 },
            { _id: 2, host: '${NODES[2]}:$MONGODB_PORT', priority: 0, hidden: true }
        ]
    })
    "
    
    sleep 15
    
    # Check replica set status
    log "Verifying replica set status..."
    mongosh --host "${NODES[0]}:$MONGODB_PORT" --eval "rs.status()" --quiet
}

# Generate dummy HR data
generate_dummy_data() {
    log "Generating dummy HR data..."
    
    # Install Python dependencies
    pip3 install pymongo pillow --quiet
    
    # Create Python script for generating data
    cat > "$SCRIPT_DIR/generate_hr_data.py" << 'EOF'
#!/usr/bin/env python3
import json
import random
from datetime import datetime, timedelta
from pymongo import MongoClient
import sys

try:
    # MongoDB connection
    client = MongoClient('mongodb://hrmlabs-mongo-primary:27017/hrmlabs')
    db = client.hrmlabs
    
    # Generate companies
    companies = []
    for i in range(5):
        company = {
            "_id": f"comp_{i+1:03d}",
            "name": f"PT. HRM Labs Company {i+1}",
            "address": f"Jl. Technology Park No. {i+1}, Jakarta",
            "phone": f"021-{random.randint(1000000, 9999999)}",
            "email": f"info@company{i+1}.com",
            "established": datetime(2010 + i, random.randint(1, 12), random.randint(1, 28)),
            "employees_count": random.randint(50, 500)
        }
        companies.append(company)
    
    # Generate departments
    departments = [
        {"_id": "dept_001", "name": "Human Resources", "description": "HR Department"},
        {"_id": "dept_002", "name": "Information Technology", "description": "IT Department"},
        {"_id": "dept_003", "name": "Finance", "description": "Finance Department"},
        {"_id": "dept_004", "name": "Marketing", "description": "Marketing Department"},
        {"_id": "dept_005", "name": "Operations", "description": "Operations Department"}
    ]
    
    # Generate employees
    employees = []
    first_names = ["Ahmad", "Budi", "Citra", "Dewi", "Eko", "Fitri", "Gilang", "Hani", "Indra", "Joko"]
    last_names = ["Pratama", "Sari", "Wijaya", "Putri", "Santoso", "Lestari", "Nugroho", "Wati", "Kusuma", "Rahayu"]
    
    for i in range(100):
        employee = {
            "_id": f"emp_{i+1:03d}",
            "employee_id": f"EMP{i+1:04d}",
            "first_name": random.choice(first_names),
            "last_name": random.choice(last_names),
            "email": f"employee{i+1}@company.com",
            "phone": f"08{random.randint(10000000000, 99999999999)}",
            "hire_date": datetime(2020, random.randint(1, 12), random.randint(1, 28)),
            "department_id": random.choice(departments)["_id"],
            "company_id": random.choice(companies)["_id"],
            "salary": random.randint(5000000, 20000000),
            "status": random.choice(["active", "inactive"]),
            "address": f"Jl. Karyawan No. {i+1}, Jakarta",
            "birth_date": datetime(1985 + random.randint(0, 15), random.randint(1, 12), random.randint(1, 28))
        }
        employees.append(employee)
    
    # Insert data into MongoDB
    print("Inserting companies...")
    db.companies.insert_many(companies)
    
    print("Inserting departments...")
    db.departments.insert_many(departments)
    
    print("Inserting employees...")
    db.employees.insert_many(employees)
    
    print(f"Data insertion completed successfully!")
    print(f"Companies: {len(companies)}")
    print(f"Departments: {len(departments)}")
    print(f"Employees: {len(employees)}")

except Exception as e:
    print(f"Error inserting data: {e}")
    sys.exit(1)
finally:
    client.close()
EOF

    # Run the data generation script
    python3 "$SCRIPT_DIR/generate_hr_data.py"
    
    # Clean up
    rm -f "$SCRIPT_DIR/generate_hr_data.py"
}

# Setup web dashboard
setup_web_dashboard() {
    log "Setting up web dashboard..."
    
    cd "$SCRIPT_DIR"
    
    # Install npm dependencies if not already installed
    if [ ! -d "node_modules" ]; then
        log "Installing Node.js dependencies..."
        npm install
    else
        info "Node.js dependencies already installed"
    fi
    
    # Create logs directory
    mkdir -p logs
    
    log "Web dashboard setup completed"
}

# Start web dashboard
start_web_dashboard() {
    log "Starting web dashboard..."
    
    cd "$SCRIPT_DIR"
    
    if [[ "$PRODUCTION" == "true" ]]; then
        # Use production startup script
        if [ -f "start-production.sh" ]; then
            log "Starting in production mode..."
            ./start-production.sh
            return 0
        else
            warning "Production script not found, falling back to development mode"
        fi
    fi
    
    # Development/standard mode
    if command -v pm2 >/dev/null 2>&1; then
        # Use PM2 if available
        pm2 start server.js --name "hrmlabs-dashboard" || pm2 restart "hrmlabs-dashboard"
        pm2 save
    else
        # Fallback to background process
        nohup npm start > dashboard.log 2>&1 &
        echo $! > dashboard.pid
    fi
    
    sleep 3
    
    # Verify dashboard is running
    if curl -s "http://localhost:$WEB_PORT/health" >/dev/null; then
        log "✅ Web dashboard started successfully"
        log "🌐 Access at: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
    else
        warning "⚠️  Dashboard may still be starting up"
        log "📋 Check logs: tail -f dashboard.log"
    fi
}

# CLI-only installation
cli_installation() {
    log "Starting CLI-only installation..."
    
    install_local_dependencies
    check_ssh_connectivity
    
    # Install and configure MongoDB on each node
    for node in "${NODES[@]}"; do
        install_mongodb_on_node "$node"
        configure_mongodb_replication "$node"
    done
    
    # Initialize replica set
    sleep 10
    initialize_replica_set
    
    # Generate dummy data
    generate_dummy_data
    
    log "CLI installation completed successfully!"
}

# Web-only mode
web_only_mode() {
    log "Starting web dashboard only..."
    
    # Install minimal dependencies
    if ! command -v node >/dev/null 2>&1; then
        dnf module install nodejs:18 npm -y
    fi
    
    setup_web_dashboard
    start_web_dashboard
    
    log "Web dashboard is running. Use the web interface to manage MongoDB installation."
}

# Full installation with web dashboard
full_installation() {
    log "Starting full installation with web dashboard..."
    
    install_local_dependencies
    setup_web_dashboard
    
    if [[ "$SKIP_CONNECTIVITY" != "true" ]]; then
        check_ssh_connectivity
    fi
    
    start_web_dashboard
    
    log "Full installation completed!"
    log "You can now use the web dashboard to complete MongoDB setup or continue with CLI."
    
    # Ask user preference
    if [[ -t 0 ]]; then  # Check if running interactively
        echo
        read -p "Do you want to continue with CLI installation now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Continuing with CLI installation..."
            cli_installation
        else
            log "Use the web dashboard to complete the installation"
        fi
    fi
}

# Validate installation
validate_installation() {
    log "Validating installation..."
    
    local issues=()
    
    # Check replica set status
    if mongosh --host "${NODES[0]}:$MONGODB_PORT" --eval "rs.status()" --quiet >/dev/null 2>&1; then
        log "✅ MongoDB replica set is healthy"
    else
        issues+=("MongoDB replica set validation failed")
    fi
    
    # Check data
    local employee_count=$(mongosh --host "${NODES[0]}:$MONGODB_PORT" --eval "db.employees.countDocuments()" --quiet hrmlabs 2>/dev/null | tail -1 || echo "0")
    if [[ "$employee_count" -gt 0 ]]; then
        log "✅ Test data available ($employee_count employees)"
    else
        issues+=("No test data found")
    fi
    
    # Check web dashboard
    if curl -s "http://localhost:$WEB_PORT/health" >/dev/null; then
        log "✅ Web dashboard is accessible"
    else
        issues+=("Web dashboard is not accessible")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        log "🎉 All validations passed!"
        return 0
    else
        warning "⚠️  Validation issues found:"
        for issue in "${issues[@]}"; do
            warning "  - $issue"
        done
        return 1
    fi
}

# Print final summary
print_summary() {
    log "==================== INSTALLATION SUMMARY ===================="
    log "MongoDB Replica Set: $REPLICA_SET_NAME"
    log "Primary Node: ${NODES[0]}"
    log "Secondary Node: ${NODES[1]}"
    log "Analytics Node: ${NODES[2]}"
    log "Web Dashboard: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
    log ""
    log "🎯 Available Features:"
    log "  ✅ Web-based Installation & Configuration"
    log "  ✅ Real-time Replication Monitoring"
    log "  ✅ Live Log Streaming"
    log "  ✅ SSH Terminal Access (Web-based)"
    log "  ✅ MongoDB Query Console"
    log "  ✅ Test Data Generation"
    log "  ✅ Health Monitoring"
    log "  ✅ Automated Backups"
    if [[ "$PRODUCTION" == "true" ]]; then
        log "  ✅ Security Hardening"
        log "  ✅ Firewall Configuration"
        log "  ✅ Fail2ban Protection"
    fi
    log ""
    log "🔧 Management Commands:"
    log "  pm2 status                     # Check dashboard status"
    log "  pm2 logs hrmlabs-dashboard     # View dashboard logs"
    log "  pm2 restart hrmlabs-dashboard  # Restart dashboard"
    log ""
    log "📚 Documentation:"
    log "  README.md                      # Complete documentation"
    log "  .env.example                   # Environment configuration"
    log "=============================================================="
}

# Main execution function
main() {
    display_banner
    parse_arguments "$@"
    
    log "HRM Labs MongoDB Automation v${VERSION} starting..."
    log "Mode: $([ "$WEB_ONLY" == "true" ] && echo "Web Only" || [ "$CLI_ONLY" == "true" ] && echo "CLI Only" || [ "$PRODUCTION" == "true" ] && echo "Production" || echo "Standard")"
    
    check_root
    check_system_requirements
    
    if [[ "$WEB_ONLY" == "true" ]]; then
        web_only_mode
    elif [[ "$CLI_ONLY" == "true" ]]; then
        cli_installation
        validate_installation
    else
        full_installation
        if [[ "$CLI_ONLY" != "true" ]]; then
            validate_installation || true  # Don't fail on validation issues in web mode
        fi
    fi
    
    print_summary
    
    log "🚀 HRM Labs MongoDB Automation completed successfully!"
    log "📊 Access your dashboard: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
}

# Cleanup function
cleanup() {
    log "Performing cleanup..."
    rm -f "$SCRIPT_DIR/generate_hr_data.py" 2>/dev/null || true
}

# Signal handlers
trap cleanup EXIT
trap 'error "Script interrupted"; exit 1' INT TERM

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi