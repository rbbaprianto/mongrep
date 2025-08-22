# HRM Labs MongoDB Management Dashboard v2.0

🚀 **Production-Ready MongoDB Cluster Management with Advanced Web Interface**

Complete automation and real-time management solution for MongoDB replication clusters with comprehensive HR data management capabilities.

## ✨ Key Features

### 🎛️ **Web-Based Management**
- **Installation Wizard**: Complete MongoDB cluster setup through web interface
- **Live Dashboard**: Real-time monitoring of all cluster components
- **Interactive Controls**: Start, stop, configure services directly from browser

### 📊 **Advanced Monitoring**
- **Real-time Replication Status**: Visual cluster health monitoring
- **Live Log Streaming**: Monitor logs from all nodes simultaneously
- **System Metrics**: CPU, memory, disk usage for all nodes
- **Performance Analytics**: Query performance and connection statistics

### 🖥️ **Integrated Terminals**
- **Web SSH**: Full SSH terminal access to all nodes via browser
- **MongoDB Query Console**: Execute queries with syntax highlighting
- **Command History**: Track and replay previous commands

### 🛠️ **Automated Operations**
- **One-Click Installation**: Deploy entire cluster with single command
- **Test Data Generation**: Create realistic HR datasets for testing
- **Health Monitoring**: Automatic service monitoring and recovery
- **Backup Management**: Scheduled backups with retention policies

### 🔒 **Production Security**
- **Firewall Configuration**: Automated security hardening
- **Fail2ban Protection**: Intrusion detection and prevention
- **Rate Limiting**: API protection against abuse
- **Log Rotation**: Automated log management

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                  HRM Labs MongoDB Cluster v2.0                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐ │
│  │  PRIMARY NODE   │  │ SECONDARY NODE  │  │  ANALYTICS NODE  │ │
│  │                 │  │                 │  │                  │ │
│  │ hrmlabs-mongo-  │◄─┤ hrmlabs-mongo-  │◄─┤ hrmlabs-mongo-   │ │
│  │ primary:27017   │  │ secondary:27017 │  │ analytics:27017  │ │
│  │                 │  │                 │  │                  │ │
│  │ Priority: 2     │  │ Priority: 1     │  │ Priority: 0      │ │
│  │ Votes: 1        │  │ Votes: 1        │  │ Hidden: true     │ │
│  └─────────────────┘  └─────────────────┘  └──────────────────┘ │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                     Web Dashboard v2.0                         │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  🌐 http://your-server:3000                                │ │
│  │                                                             │ │
│  │  📊 Live Monitoring  🖥️  SSH Terminals  ⚙️  Configuration   │ │
│  │  📝 Query Console   📋 Log Streaming   🔧 System Control   │ │
│  │  🗃️  Test Data      💾 Backups        🔒 Security         │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Option 1: Full Installation with Web Dashboard (Recommended)

```bash
# Download and run the automation script
chmod +x hrmlabs-mongo-automation.sh
sudo ./hrmlabs-mongo-automation.sh
```

### Option 2: Web Dashboard Only

```bash
# Start only the web dashboard (for existing MongoDB clusters)
sudo ./hrmlabs-mongo-automation.sh --web-only
```

### Option 3: Production Deployment

```bash
# Full production setup with security hardening
sudo ./hrmlabs-mongo-automation.sh --production
```

### Option 4: CLI Only (Traditional)

```bash
# Traditional command-line installation
sudo ./hrmlabs-mongo-automation.sh --cli-only
```

## 📋 Prerequisites

### System Requirements
- **OS**: Rocky Linux 9, CentOS 9, or RHEL 9
- **Memory**: Minimum 2GB RAM (4GB+ recommended)
- **Storage**: 5GB+ free disk space
- **Network**: SSH connectivity between nodes

### Node Configuration
Ensure the following hostnames are configured and accessible:
- `hrmlabs-mongo-primary` (Primary MongoDB node)
- `hrmlabs-mongo-secondary` (Secondary MongoDB node)  
- `hrmlabs-mongo-analytics` (Analytics/Hidden node)

### SSH Access
Configure passwordless SSH access to all nodes:
```bash
# Generate SSH key (if not exists)
ssh-keygen -t rsa -b 4096 -C "hrmlabs-automation"

# Copy public key to all nodes
ssh-copy-id root@hrmlabs-mongo-primary
ssh-copy-id root@hrmlabs-mongo-secondary
ssh-copy-id root@hrmlabs-mongo-analytics
```

## 🎛️ Web Dashboard Features

### Installation Wizard
- **Guided Setup**: Step-by-step cluster installation
- **Progress Tracking**: Real-time installation progress
- **Error Handling**: Detailed error reporting and recovery options
- **Live Logs**: Installation logs streamed in real-time

### Monitoring Dashboard
- **Cluster Status**: Visual replica set health indicators
- **Node Metrics**: CPU, memory, disk usage per node
- **Connection Stats**: Active connections and performance metrics
- **Data Statistics**: Document counts, storage usage

### Interactive Terminals
- **SSH Access**: Full terminal access to each node via web browser
- **Multiple Sessions**: Open multiple terminals simultaneously
- **Copy/Paste Support**: Easy command sharing
- **Resize Support**: Responsive terminal sizing

### Query Console
- **Syntax Highlighting**: MongoDB query syntax support
- **Query History**: Track and replay previous queries
- **Multi-Node Support**: Execute queries on any cluster node
- **Result Formatting**: Pretty-printed JSON results

### Log Management
- **Live Streaming**: Real-time log tailing from all nodes
- **Node Selection**: Switch between different node logs
- **Auto-Scroll**: Automatic scrolling to latest entries
- **Search & Filter**: Find specific log entries

### Test Data Management
- **HR Dataset Generation**: Create realistic employee, company, department data
- **Configurable Size**: Specify number of records to generate
- **Relationship Mapping**: Properly linked data across collections
- **Bulk Operations**: Efficient data insertion and management

## 📁 Project Structure

```
/workspace/
├── hrmlabs-mongo-automation.sh    # Main automation script v2.0
├── start-production.sh            # Production deployment script
├── server.js                      # Web dashboard backend
├── package.json                   # Node.js dependencies
├── ecosystem.config.js            # PM2 configuration
├── .env.example                   # Environment template
├── accounts.json.template         # Node configuration template
├── public/
│   └── index.html                # Web dashboard frontend
├── logs/                         # Application logs
│   ├── combined.log
│   ├── error.log
│   └── pm2-*.log
└── backups/                      # Automated backups
    └── backup_*.tar.gz
```

## ⚙️ Configuration

### Environment Variables
Copy `.env.example` to `.env` and configure:

```bash
# Server Configuration
NODE_ENV=production
PORT=3000

# MongoDB Configuration
MONGODB_PORT=27017
REPLICA_SET_NAME=hrmlabsrs

# SSH Configuration
SSH_PASSWORD=your_password_here
SSH_PRIVATE_KEY_PATH=/root/.ssh/id_rsa

# Security
JWT_SECRET=your_jwt_secret_change_in_production
RATE_LIMIT_MAX_REQUESTS=100
```

### Node Configuration
Update `accounts.json` with your node details:

```json
{
  "nodes": [
    {
      "name": "hrmlabs-mongo-primary",
      "host": "10.0.1.10",
      "user": "root",
      "role": "primary"
    },
    {
      "name": "hrmlabs-mongo-secondary", 
      "host": "10.0.1.11",
      "user": "root",
      "role": "secondary"
    },
    {
      "name": "hrmlabs-mongo-analytics",
      "host": "10.0.1.12", 
      "user": "root",
      "role": "analytics"
    }
  ]
}
```

## 🔧 Management Commands

### Script Options
```bash
# Show help and available options
./hrmlabs-mongo-automation.sh --help

# Show version information
./hrmlabs-mongo-automation.sh --version

# Start only web dashboard
./hrmlabs-mongo-automation.sh --web-only

# CLI installation only
./hrmlabs-mongo-automation.sh --cli-only

# Production deployment with security
./hrmlabs-mongo-automation.sh --production

# Custom port
./hrmlabs-mongo-automation.sh --port 8080

# Skip dependency installation
./hrmlabs-mongo-automation.sh --skip-deps

# Skip connectivity checks
./hrmlabs-mongo-automation.sh --skip-connectivity
```

### PM2 Management
```bash
# Check application status
pm2 status

# View dashboard logs
pm2 logs hrmlabs-mongodb-dashboard

# Restart dashboard
pm2 restart hrmlabs-mongodb-dashboard

# Stop dashboard
pm2 stop hrmlabs-mongodb-dashboard

# Monitor resources
pm2 monit
```

### MongoDB Operations
```bash
# Check replica set status
mongosh --host hrmlabs-mongo-primary:27017 --eval "rs.status()"

# View cluster configuration
mongosh --host hrmlabs-mongo-primary:27017 --eval "rs.conf()"

# Check database statistics
mongosh --host hrmlabs-mongo-primary:27017 hrmlabs --eval "db.stats()"
```

## 📊 Generated Test Data

The system generates comprehensive HR test data including:

### Companies (5 records)
- Company information, addresses, contact details
- Employee counts and establishment dates

### Departments (5 records)
- HR, IT, Finance, Marketing, Operations
- Department descriptions and hierarchies

### Employees (100 records)
- Personal information (names, contacts, addresses)
- Employment details (hire dates, positions, salaries)
- Status tracking (active/inactive)

### Sample Queries
```javascript
// Count employees by department
db.employees.aggregate([
  {$group: {_id: "$department_id", count: {$sum: 1}}}
])

// Find active employees
db.employees.find({status: "active"}).limit(10)

// Get company statistics
db.companies.aggregate([
  {$group: {_id: null, totalEmployees: {$sum: "$employees_count"}}}
])

// Employee salary analysis
db.employees.aggregate([
  {$group: {_id: "$department_id", avgSalary: {$avg: "$salary"}}}
])
```

## 🔒 Security Features

### Production Security (--production mode)
- **Firewall Configuration**: Automated iptables/firewalld setup
- **Fail2ban Protection**: Intrusion detection and IP blocking
- **SSL/TLS**: HTTPS encryption for web dashboard
- **Rate Limiting**: API request throttling
- **Log Monitoring**: Security event tracking

### Network Security
- **Port Restrictions**: MongoDB ports limited to cluster nodes
- **SSH Hardening**: Key-based authentication enforcement
- **Service Isolation**: Application-specific user accounts

### Application Security
- **Input Validation**: SQL injection prevention
- **CSRF Protection**: Cross-site request forgery prevention
- **Helmet.js**: HTTP security headers
- **Session Management**: Secure session handling

## 🔍 Monitoring & Alerting

### Health Checks
- **Automatic Health Monitoring**: Every 5 minutes
- **Service Recovery**: Automatic restart on failure
- **Email Alerts**: Notification on critical issues
- **Uptime Tracking**: Service availability metrics

### Log Management
- **Centralized Logging**: All services log to structured files
- **Log Rotation**: Automatic log rotation and compression
- **Log Levels**: Configurable logging verbosity
- **Error Tracking**: Structured error reporting

### Performance Monitoring
- **Resource Usage**: CPU, memory, disk monitoring
- **Query Performance**: Slow query identification
- **Connection Tracking**: Active connection monitoring
- **Throughput Metrics**: Operations per second tracking

## 💾 Backup & Recovery

### Automated Backups
- **Daily Backups**: Scheduled at 2 AM daily
- **Retention Policy**: 30-day backup retention
- **Compression**: Gzip compression for storage efficiency
- **Verification**: Backup integrity checking

### Manual Backup
```bash
# Create immediate backup
./backup.sh

# Restore from backup
mongorestore --host hrmlabs-mongo-primary:27017 /path/to/backup/
```

### Disaster Recovery
- **Replica Set Recovery**: Automatic failover procedures
- **Data Restoration**: Point-in-time recovery options
- **Configuration Backup**: System configuration preservation

## 🚨 Troubleshooting

### Common Issues

#### Dashboard Not Accessible
```bash
# Check dashboard status
pm2 status hrmlabs-mongodb-dashboard

# Check port availability
netstat -tulpn | grep :3000

# Restart dashboard
pm2 restart hrmlabs-mongodb-dashboard
```

#### MongoDB Connection Issues
```bash
# Check MongoDB service status
ssh root@hrmlabs-mongo-primary "systemctl status mongod"

# Check MongoDB logs
ssh root@hrmlabs-mongo-primary "tail -f /var/log/mongodb/mongod.log"

# Test connectivity
mongosh --host hrmlabs-mongo-primary:27017 --eval "db.runCommand('ping')"
```

#### SSH Connection Problems
```bash
# Test SSH connectivity
ssh -v root@hrmlabs-mongo-primary

# Check SSH service
ssh root@hrmlabs-mongo-primary "systemctl status sshd"

# Verify SSH keys
ssh-add -l
```

#### Replica Set Issues
```bash
# Check replica set status
mongosh --host hrmlabs-mongo-primary:27017 --eval "rs.status()"

# Reconfigure replica set
mongosh --host hrmlabs-mongo-primary:27017 --eval "rs.reconfig(rs.conf())"

# Force primary election
mongosh --host hrmlabs-mongo-primary:27017 --eval "rs.stepDown()"
```

### Log Locations
- **Dashboard Logs**: `/workspace/logs/combined.log`
- **MongoDB Logs**: `/var/log/mongodb/mongod.log` (on each node)
- **System Logs**: `/var/log/messages`
- **PM2 Logs**: `/workspace/logs/pm2-*.log`

### Performance Tuning
```bash
# Monitor resource usage
htop

# Check disk I/O
iotop

# Monitor network connections
ss -tuln

# MongoDB performance
mongosh --host hrmlabs-mongo-primary:27017 --eval "db.serverStatus()"
```

## 🔄 Updates & Maintenance

### Updating the Dashboard
```bash
# Pull latest changes
git pull origin main

# Install new dependencies
npm install

# Restart dashboard
pm2 restart hrmlabs-mongodb-dashboard
```

### MongoDB Maintenance
```bash
# Compact databases
mongosh --host hrmlabs-mongo-primary:27017 hrmlabs --eval "db.runCommand({compact: 'employees'})"

# Rebuild indexes
mongosh --host hrmlabs-mongo-primary:27017 hrmlabs --eval "db.employees.reIndex()"

# Check database integrity
mongosh --host hrmlabs-mongo-primary:27017 hrmlabs --eval "db.runCommand({validate: 'employees'})"
```

## 📈 Scaling & Performance

### Horizontal Scaling
- **Add Secondary Nodes**: Expand read capacity
- **Sharding Support**: Distribute data across multiple shards
- **Load Balancing**: Distribute client connections

### Performance Optimization
- **Index Optimization**: Efficient query indexing
- **Connection Pooling**: Optimal connection management
- **Memory Tuning**: MongoDB memory configuration
- **Disk Optimization**: SSD storage recommendations

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit changes**: `git commit -m 'Add amazing feature'`
4. **Push to branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Documentation
- **GitHub Wiki**: Comprehensive documentation
- **API Reference**: REST API documentation
- **Video Tutorials**: Step-by-step guides

### Community Support
- **GitHub Issues**: Bug reports and feature requests
- **Discussions**: Community Q&A and discussions
- **Discord**: Real-time community chat

### Commercial Support
For enterprise support, training, and custom development:
- **Email**: support@hrmlabs.com
- **Website**: https://hrmlabs.com/support

---

## 🎯 Roadmap

### Version 2.1 (Q2 2024)
- [ ] **Authentication System**: User login and role-based access
- [ ] **API Documentation**: Swagger/OpenAPI integration
- [ ] **Mobile Dashboard**: Responsive mobile interface
- [ ] **Advanced Analytics**: Custom reporting and dashboards

### Version 2.2 (Q3 2024)
- [ ] **Multi-Cluster Support**: Manage multiple MongoDB clusters
- [ ] **Kubernetes Integration**: Container orchestration support
- [ ] **Advanced Monitoring**: Prometheus/Grafana integration
- [ ] **Automated Scaling**: Auto-scaling based on load

### Version 3.0 (Q4 2024)
- [ ] **Microservices Architecture**: Distributed system design
- [ ] **GraphQL API**: Modern API interface
- [ ] **AI-Powered Insights**: Machine learning analytics
- [ ] **Cloud Integration**: AWS/Azure/GCP support

---

**© 2024 HRM Labs - Advanced MongoDB Management Solutions**

*Built with ❤️ for the MongoDB community*