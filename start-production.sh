#!/bin/bash

# HRM Labs MongoDB Dashboard Production Startup Script
# This script handles the complete startup process for production deployment

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
PID_FILE="$SCRIPT_DIR/dashboard.pid"
BACKUP_DIR="$SCRIPT_DIR/backups"

# Logging functions
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root for production deployment"
        exit 1
    fi
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$SCRIPT_DIR/tmp"
    
    # Set proper permissions
    chmod 755 "$LOG_DIR"
    chmod 755 "$BACKUP_DIR"
    chmod 755 "$SCRIPT_DIR/tmp"
}

# Install system dependencies
install_system_dependencies() {
    log "Installing system dependencies..."
    
    # Update system packages
    dnf update -y
    
    # Install required packages
    dnf install -y \
        nodejs npm \
        python3 python3-pip \
        git curl wget \
        logrotate \
        firewalld \
        fail2ban \
        htop \
        vim
    
    # Install global npm packages
    npm install -g pm2 nodemon
    
    # Install Python packages
    pip3 install pymongo pillow requests
    
    log "System dependencies installed successfully"
}

# Setup firewall
setup_firewall() {
    log "Configuring firewall..."
    
    # Start firewalld
    systemctl enable firewalld
    systemctl start firewalld
    
    # Allow SSH
    firewall-cmd --permanent --add-service=ssh
    
    # Allow HTTP and HTTPS
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    
    # Allow dashboard port
    firewall-cmd --permanent --add-port=3000/tcp
    
    # Allow MongoDB port (only from cluster nodes)
    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='10.0.0.0/8' port protocol='tcp' port='27017' accept"
    
    # Reload firewall
    firewall-cmd --reload
    
    log "Firewall configured successfully"
}

# Setup fail2ban
setup_fail2ban() {
    log "Configuring fail2ban..."
    
    # Create custom jail for dashboard
    cat > /etc/fail2ban/jail.d/hrmlabs-dashboard.conf << 'EOF'
[hrmlabs-dashboard]
enabled = true
port = 3000
filter = hrmlabs-dashboard
logpath = /workspace/logs/combined.log
maxretry = 5
bantime = 3600
findtime = 600
EOF

    # Create custom filter
    cat > /etc/fail2ban/filter.d/hrmlabs-dashboard.conf << 'EOF'
[Definition]
failregex = ^.*\[error\].*client: <HOST>.*$
            ^.*\[warn\].*Too many requests.*client: <HOST>.*$
ignoreregex =
EOF

    # Enable and start fail2ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log "Fail2ban configured successfully"
}

# Setup log rotation
setup_log_rotation() {
    log "Setting up log rotation..."
    
    cat > /etc/logrotate.d/hrmlabs-dashboard << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        pm2 reloadLogs
    endscript
}
EOF
    
    log "Log rotation configured successfully"
}

# Install application dependencies
install_app_dependencies() {
    log "Installing application dependencies..."
    
    cd "$SCRIPT_DIR"
    
    # Install Node.js dependencies
    npm install --production
    
    # Verify critical packages
    node -e "
        const requiredPackages = ['express', 'socket.io', 'mongodb', 'node-ssh', 'winston'];
        requiredPackages.forEach(pkg => {
            try {
                require(pkg);
                console.log('✓', pkg, 'installed');
            } catch (e) {
                console.error('✗', pkg, 'missing');
                process.exit(1);
            }
        });
    "
    
    log "Application dependencies installed successfully"
}

# Setup environment configuration
setup_environment() {
    log "Setting up environment configuration..."
    
    # Copy environment template if .env doesn't exist
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        if [ -f "$SCRIPT_DIR/.env.example" ]; then
            cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
            warning "Created .env from template. Please update with your actual values."
        else
            # Create basic .env file
            cat > "$SCRIPT_DIR/.env" << 'EOF'
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
SSH_PASSWORD=
MONGODB_PORT=27017
REPLICA_SET_NAME=hrmlabsrs
EOF
            warning "Created basic .env file. Please update with your configuration."
        fi
    fi
    
    # Set proper permissions
    chmod 600 "$SCRIPT_DIR/.env"
    
    log "Environment configuration ready"
}

# Check MongoDB connectivity
check_mongodb_connectivity() {
    log "Checking MongoDB connectivity..."
    
    local nodes=("hrmlabs-mongo-primary" "hrmlabs-mongo-secondary" "hrmlabs-mongo-analytics")
    local failed_nodes=()
    
    for node in "${nodes[@]}"; do
        if ! nc -z "$node" 27017 2>/dev/null; then
            failed_nodes+=("$node")
        else
            info "✓ $node:27017 is reachable"
        fi
    done
    
    if [ ${#failed_nodes[@]} -gt 0 ]; then
        warning "Some MongoDB nodes are not reachable: ${failed_nodes[*]}"
        warning "The application will start but some features may not work properly"
    else
        log "All MongoDB nodes are reachable"
    fi
}

# Check SSH connectivity
check_ssh_connectivity() {
    log "Checking SSH connectivity..."
    
    local nodes=("hrmlabs-mongo-primary" "hrmlabs-mongo-secondary" "hrmlabs-mongo-analytics")
    local failed_nodes=()
    
    for node in "${nodes[@]}"; do
        if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$node" "echo 'SSH OK'" >/dev/null 2>&1; then
            failed_nodes+=("$node")
        else
            info "✓ SSH to $node is working"
        fi
    done
    
    if [ ${#failed_nodes[@]} -gt 0 ]; then
        warning "SSH to some nodes failed: ${failed_nodes[*]}"
        warning "SSH terminal features may not work for these nodes"
    else
        log "SSH connectivity to all nodes verified"
    fi
}

# Start application with PM2
start_application() {
    log "Starting application with PM2..."
    
    cd "$SCRIPT_DIR"
    
    # Stop existing instances
    pm2 stop hrmlabs-mongodb-dashboard 2>/dev/null || true
    pm2 delete hrmlabs-mongodb-dashboard 2>/dev/null || true
    
    # Start with ecosystem config
    if [ -f "ecosystem.config.js" ]; then
        pm2 start ecosystem.config.js --env production
    else
        # Fallback to direct start
        pm2 start server.js --name hrmlabs-mongodb-dashboard --env production
    fi
    
    # Save PM2 configuration
    pm2 save
    
    # Setup PM2 startup
    pm2 startup systemd -u root --hp /root
    
    log "Application started successfully"
}

# Setup health monitoring
setup_health_monitoring() {
    log "Setting up health monitoring..."
    
    # Create health check script
    cat > "$SCRIPT_DIR/health-check.sh" << 'EOF'
#!/bin/bash

HEALTH_URL="http://localhost:3000/health"
LOG_FILE="/workspace/logs/health-check.log"

# Function to log with timestamp
log_health() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check application health
if curl -f -s "$HEALTH_URL" > /dev/null; then
    log_health "✓ Application is healthy"
    exit 0
else
    log_health "✗ Application health check failed"
    
    # Try to restart the application
    log_health "Attempting to restart application..."
    pm2 restart hrmlabs-mongodb-dashboard
    
    # Wait a bit and check again
    sleep 10
    if curl -f -s "$HEALTH_URL" > /dev/null; then
        log_health "✓ Application restarted successfully"
        exit 0
    else
        log_health "✗ Application restart failed"
        exit 1
    fi
fi
EOF
    
    chmod +x "$SCRIPT_DIR/health-check.sh"
    
    # Add to crontab for periodic health checks
    (crontab -l 2>/dev/null; echo "*/5 * * * * $SCRIPT_DIR/health-check.sh") | crontab -
    
    log "Health monitoring configured"
}

# Setup backup system
setup_backup_system() {
    log "Setting up backup system..."
    
    # Create backup script
    cat > "$SCRIPT_DIR/backup.sh" << 'EOF'
#!/bin/bash

BACKUP_DIR="/workspace/backups"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/workspace/logs/backup.log"

# Function to log with timestamp
log_backup() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_backup "Starting backup process..."

# Create backup directory for this run
BACKUP_PATH="$BACKUP_DIR/backup_$DATE"
mkdir -p "$BACKUP_PATH"

# Backup MongoDB data
log_backup "Backing up MongoDB data..."
if command -v mongodump >/dev/null 2>&1; then
    mongodump --host hrmlabs-mongo-primary:27017 --db hrmlabs --out "$BACKUP_PATH/mongodb"
    if [ $? -eq 0 ]; then
        log_backup "✓ MongoDB backup completed"
    else
        log_backup "✗ MongoDB backup failed"
    fi
else
    log_backup "⚠ mongodump not available, skipping MongoDB backup"
fi

# Backup configuration files
log_backup "Backing up configuration files..."
cp -r /workspace/*.json /workspace/.env /workspace/ecosystem.config.js "$BACKUP_PATH/config/" 2>/dev/null || true

# Compress backup
log_backup "Compressing backup..."
cd "$BACKUP_DIR"
tar -czf "backup_$DATE.tar.gz" "backup_$DATE"
rm -rf "backup_$DATE"

# Clean old backups (keep last 30 days)
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +30 -delete

log_backup "Backup process completed: backup_$DATE.tar.gz"
EOF
    
    chmod +x "$SCRIPT_DIR/backup.sh"
    
    # Add to crontab for daily backups at 2 AM
    (crontab -l 2>/dev/null; echo "0 2 * * * $SCRIPT_DIR/backup.sh") | crontab -
    
    log "Backup system configured"
}

# Display startup information
display_startup_info() {
    log "==================== HRM Labs MongoDB Dashboard v2.0 ===================="
    log "🚀 Production deployment completed successfully!"
    log ""
    log "📊 Dashboard URL: http://$(hostname -I | awk '{print $1}'):3000"
    log "🔧 Health Check: http://$(hostname -I | awk '{print $1}'):3000/health"
    log "📁 Log Directory: $LOG_DIR"
    log "💾 Backup Directory: $BACKUP_DIR"
    log ""
    log "🔧 Management Commands:"
    log "  pm2 status                    - Check application status"
    log "  pm2 logs hrmlabs-mongodb-dashboard - View application logs"
    log "  pm2 restart hrmlabs-mongodb-dashboard - Restart application"
    log "  pm2 stop hrmlabs-mongodb-dashboard - Stop application"
    log ""
    log "📋 Features Available:"
    log "  ✅ Web-based Installation Control"
    log "  ✅ Live MongoDB Replication Monitoring"
    log "  ✅ Real-time Log Streaming"
    log "  ✅ SSH Terminal Access"
    log "  ✅ MongoDB Query Console"
    log "  ✅ Test Data Generation"
    log "  ✅ System Health Monitoring"
    log "  ✅ Automated Backups"
    log "  ✅ Security Hardening"
    log ""
    log "🔒 Security Features:"
    log "  ✅ Firewall Configuration"
    log "  ✅ Fail2ban Protection"
    log "  ✅ Rate Limiting"
    log "  ✅ Log Rotation"
    log ""
    log "⚠️  Important Notes:"
    log "  - Update .env file with your actual configuration"
    log "  - Ensure SSH keys are properly configured for all nodes"
    log "  - Monitor logs regularly: tail -f $LOG_DIR/combined.log"
    log "  - Backups are created daily at 2 AM"
    log "=========================================================================="
}

# Main execution
main() {
    log "Starting HRM Labs MongoDB Dashboard Production Setup..."
    
    check_root
    create_directories
    install_system_dependencies
    setup_firewall
    setup_fail2ban
    setup_log_rotation
    install_app_dependencies
    setup_environment
    check_mongodb_connectivity
    check_ssh_connectivity
    start_application
    setup_health_monitoring
    setup_backup_system
    
    # Wait a moment for the application to fully start
    sleep 5
    
    # Verify the application is running
    if curl -f -s "http://localhost:3000/health" > /dev/null; then
        log "✅ Application is running and healthy"
    else
        warning "⚠️  Application may still be starting up. Check logs with: pm2 logs"
    fi
    
    display_startup_info
}

# Signal handlers
trap 'error "Script interrupted"; exit 1' INT TERM

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi