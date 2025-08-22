const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const { MongoClient } = require('mongodb');
const NodeSSH = require('node-ssh');
const fs = require('fs').promises;
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const winston = require('winston');
const { spawn } = require('child_process');
const WebSocket = require('ws');
const pty = require('node-pty');
const { v4: uuidv4 } = require('uuid');
const archiver = require('archiver');

// Enhanced logging setup
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: { service: 'hrmlabs-dashboard' },
    transports: [
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' }),
        new winston.transports.Console({
            format: winston.format.simple()
        })
    ]
});

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST", "PUT", "DELETE"]
    }
});

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
});

// Enhanced middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com"],
            scriptSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com", "https://cdn.socket.io"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'", "ws:", "wss:"],
            fontSrc: ["'self'", "https://cdnjs.cloudflare.com"]
        }
    }
}));
app.use(compression());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
app.use(cors());
app.use(limiter);
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// Configuration
const CONFIG = {
    NODES: ['hrmlabs-mongo-primary', 'hrmlabs-mongo-secondary', 'hrmlabs-mongo-analytics'],
    MONGODB_PORT: 27017,
    SSH_USER: 'root',
    REPLICA_SET_NAME: 'hrmlabsrs',
    WEB_PORT: process.env.PORT || 3000
};

// Global state management
const state = {
    mongoClients: {},
    sshClients: {},
    terminals: {},
    installationStatus: {
        phase: 'idle', // idle, installing, configuring, testing, completed, error
        progress: 0,
        currentStep: '',
        logs: []
    },
    systemStats: {
        lastUpdated: null,
        replicationStatus: null,
        nodeStats: {}
    }
};

// Utility functions
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

const logToState = (message, type = 'info') => {
    const logEntry = {
        timestamp: new Date().toISOString(),
        type,
        message
    };
    state.installationStatus.logs.push(logEntry);
    if (state.installationStatus.logs.length > 1000) {
        state.installationStatus.logs = state.installationStatus.logs.slice(-500);
    }
    io.emit('installation-log', logEntry);
    logger[type](message);
};

const updateInstallationStatus = (phase, progress, step) => {
    state.installationStatus.phase = phase;
    state.installationStatus.progress = progress;
    state.installationStatus.currentStep = step;
    io.emit('installation-status', state.installationStatus);
    logToState(`Phase: ${phase}, Progress: ${progress}%, Step: ${step}`);
};

// MongoDB connection management
async function initializeMongoConnections() {
    logToState('Initializing MongoDB connections...');
    for (const node of CONFIG.NODES) {
        try {
            const client = new MongoClient(`mongodb://${node}:${CONFIG.MONGODB_PORT}/hrmlabs`, {
                serverSelectionTimeoutMS: 5000,
                connectTimeoutMS: 10000,
                maxPoolSize: 10
            });
            await client.connect();
            state.mongoClients[node] = client;
            logToState(`Connected to MongoDB on ${node}`, 'info');
        } catch (error) {
            logToState(`Failed to connect to MongoDB on ${node}: ${error.message}`, 'error');
        }
    }
}

// SSH connection management
async function initializeSSHConnections() {
    logToState('Initializing SSH connections...');
    for (const node of CONFIG.NODES) {
        try {
            const ssh = new NodeSSH();
            
            // Try different authentication methods
            let connected = false;
            
            // Try with private key
            try {
                const privateKey = await fs.readFile('/root/.ssh/id_rsa', 'utf8');
                await ssh.connect({
                    host: node,
                    username: CONFIG.SSH_USER,
                    privateKey: privateKey,
                    readyTimeout: 10000
                });
                connected = true;
            } catch (keyError) {
                // Try with password if available
                if (process.env.SSH_PASSWORD) {
                    await ssh.connect({
                        host: node,
                        username: CONFIG.SSH_USER,
                        password: process.env.SSH_PASSWORD,
                        readyTimeout: 10000
                    });
                    connected = true;
                }
            }
            
            if (connected) {
                state.sshClients[node] = ssh;
                logToState(`SSH connected to ${node}`, 'info');
            } else {
                throw new Error('No valid authentication method found');
            }
        } catch (error) {
            logToState(`Failed to SSH connect to ${node}: ${error.message}`, 'error');
        }
    }
}

// Enhanced replica set status
async function getReplicaSetStatus() {
    try {
        const primaryClient = state.mongoClients[CONFIG.NODES[0]];
        if (!primaryClient) return null;
        
        const admin = primaryClient.db().admin();
        const status = await admin.command({ replSetGetStatus: 1 });
        
        // Get additional stats
        const serverStatus = await admin.command({ serverStatus: 1 });
        const dbStats = await primaryClient.db('hrmlabs').stats();
        
        state.systemStats.replicationStatus = {
            ...status,
            serverStatus: {
                uptime: serverStatus.uptime,
                connections: serverStatus.connections,
                network: serverStatus.network,
                opcounters: serverStatus.opcounters
            },
            dbStats
        };
        
        state.systemStats.lastUpdated = new Date();
        return state.systemStats.replicationStatus;
    } catch (error) {
        logToState(`Error getting replica set status: ${error.message}`, 'error');
        return null;
    }
}

// Enhanced MongoDB logs
async function getMongoLogs(node, lines = 100) {
    try {
        const ssh = state.sshClients[node];
        if (!ssh) return 'SSH connection not available';
        
        const result = await ssh.execCommand(`tail -n ${lines} /var/log/mongodb/mongod.log`);
        return result.stdout;
    } catch (error) {
        return `Error getting logs: ${error.message}`;
    }
}

// Execute MongoDB query with enhanced error handling
async function executeMongoQuery(node, database, query) {
    try {
        const client = state.mongoClients[node];
        if (!client) return { error: 'MongoDB connection not available' };
        
        const db = client.db(database);
        
        // Handle different query types
        let result;
        if (query.startsWith('db.')) {
            // Use eval for complex queries
            result = await db.admin().command({ eval: query });
        } else {
            // Try to parse as JSON for direct operations
            try {
                const parsedQuery = JSON.parse(query);
                result = await db.admin().command(parsedQuery);
            } catch {
                result = await db.admin().command({ eval: query });
            }
        }
        
        return result;
    } catch (error) {
        return { error: error.message };
    }
}

// Enhanced SSH command execution
async function executeSSHCommand(node, command) {
    try {
        const ssh = state.sshClients[node];
        if (!ssh) return { error: 'SSH connection not available' };
        
        const result = await ssh.execCommand(command, {
            execOptions: { maxBuffer: 1024 * 1024 * 10 } // 10MB buffer
        });
        
        return {
            stdout: result.stdout,
            stderr: result.stderr,
            code: result.code,
            command: command,
            node: node,
            timestamp: new Date().toISOString()
        };
    } catch (error) {
        return { error: error.message, command, node };
    }
}

// Installation and configuration functions
async function installLocalDependencies() {
    updateInstallationStatus('installing', 10, 'Installing local dependencies');
    
    const commands = [
        'dnf update -y',
        'dnf module install nodejs:18 npm -y',
        'dnf install python3 python3-pip -y',
        'dnf install openssh-clients curl wget git -y'
    ];
    
    for (let i = 0; i < commands.length; i++) {
        try {
            logToState(`Executing: ${commands[i]}`);
            const result = await executeCommand(commands[i]);
            if (result.code !== 0) {
                throw new Error(`Command failed: ${result.stderr}`);
            }
            updateInstallationStatus('installing', 10 + (i + 1) * 5, `Completed: ${commands[i]}`);
        } catch (error) {
            logToState(`Failed to execute ${commands[i]}: ${error.message}`, 'error');
            throw error;
        }
    }
}

async function setupMongoRepository() {
    updateInstallationStatus('installing', 30, 'Setting up MongoDB repository');
    
    const repoContent = `[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc`;
    
    try {
        await fs.writeFile('/etc/yum.repos.d/mongodb-org-7.0.repo', repoContent);
        const result = await executeCommand('dnf install mongodb-mongosh mongodb-database-tools -y');
        if (result.code !== 0) {
            throw new Error(`MongoDB tools installation failed: ${result.stderr}`);
        }
        logToState('MongoDB repository and tools installed successfully');
    } catch (error) {
        logToState(`Failed to setup MongoDB repository: ${error.message}`, 'error');
        throw error;
    }
}

async function checkSSHConnectivity() {
    updateInstallationStatus('installing', 40, 'Checking SSH connectivity');
    
    for (const node of CONFIG.NODES) {
        try {
            const result = await executeCommand(`ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${CONFIG.SSH_USER}@${node} "echo 'SSH OK'"`);
            if (result.code === 0) {
                logToState(`SSH connectivity to ${node}: OK`);
            } else {
                throw new Error(`SSH connection failed to ${node}`);
            }
        } catch (error) {
            logToState(`Cannot connect to ${node} via SSH: ${error.message}`, 'error');
            throw error;
        }
    }
}

async function installMongoDBOnNodes() {
    updateInstallationStatus('installing', 50, 'Installing MongoDB on nodes');
    
    const installScript = `#!/bin/bash
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

echo "MongoDB installed successfully on $(hostname)"`;

    for (let i = 0; i < CONFIG.NODES.length; i++) {
        const node = CONFIG.NODES[i];
        try {
            logToState(`Installing MongoDB on ${node}...`);
            const ssh = state.sshClients[node];
            if (!ssh) {
                throw new Error(`No SSH connection to ${node}`);
            }
            
            const result = await ssh.execCommand(installScript);
            if (result.code !== 0) {
                throw new Error(`Installation failed on ${node}: ${result.stderr}`);
            }
            
            logToState(`MongoDB installed successfully on ${node}`);
            updateInstallationStatus('installing', 50 + (i + 1) * 10, `MongoDB installed on ${node}`);
        } catch (error) {
            logToState(`Failed to install MongoDB on ${node}: ${error.message}`, 'error');
            throw error;
        }
    }
}

async function configureReplication() {
    updateInstallationStatus('configuring', 80, 'Configuring MongoDB replication');
    
    const mongoConfig = `storage:
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
  replSetName: ${CONFIG.REPLICA_SET_NAME}

security:
  authorization: disabled`;

    for (let i = 0; i < CONFIG.NODES.length; i++) {
        const node = CONFIG.NODES[i];
        try {
            logToState(`Configuring replication on ${node}...`);
            const ssh = state.sshClients[node];
            
            const configScript = `
systemctl stop mongod
cp /etc/mongod.conf /etc/mongod.conf.backup
cat > /etc/mongod.conf << 'EOF'
${mongoConfig}
EOF
chown mongod:mongod /etc/mongod.conf
chmod 644 /etc/mongod.conf
mkdir -p /var/log/mongodb /var/run/mongodb
chown -R mongod:mongod /var/log/mongodb /var/run/mongodb
systemctl start mongod
systemctl enable mongod
sleep 10
echo "Replication configured on $(hostname)"
`;
            
            const result = await ssh.execCommand(configScript);
            if (result.code !== 0) {
                throw new Error(`Configuration failed on ${node}: ${result.stderr}`);
            }
            
            logToState(`Replication configured on ${node}`);
            updateInstallationStatus('configuring', 80 + (i + 1) * 5, `Replication configured on ${node}`);
        } catch (error) {
            logToState(`Failed to configure replication on ${node}: ${error.message}`, 'error');
            throw error;
        }
    }
}

async function initializeReplicaSet() {
    updateInstallationStatus('configuring', 95, 'Initializing replica set');
    
    try {
        // Wait for MongoDB to be ready
        await sleep(15000);
        
        const initCommand = `rs.initiate({
            _id: '${CONFIG.REPLICA_SET_NAME}',
            members: [
                { _id: 0, host: '${CONFIG.NODES[0]}:${CONFIG.MONGODB_PORT}', priority: 2 },
                { _id: 1, host: '${CONFIG.NODES[1]}:${CONFIG.MONGODB_PORT}', priority: 1 },
                { _id: 2, host: '${CONFIG.NODES[2]}:${CONFIG.MONGODB_PORT}', priority: 0, hidden: true }
            ]
        })`;
        
        const result = await executeCommand(`mongosh --host ${CONFIG.NODES[0]}:${CONFIG.MONGODB_PORT} --eval "${initCommand}"`);
        if (result.code !== 0) {
            throw new Error(`Replica set initialization failed: ${result.stderr}`);
        }
        
        logToState('Replica set initialized successfully');
        await sleep(15000); // Wait for election
        
        // Verify replica set status
        const statusResult = await executeCommand(`mongosh --host ${CONFIG.NODES[0]}:${CONFIG.MONGODB_PORT} --eval "rs.status()"`);
        if (statusResult.code === 0) {
            logToState('Replica set is healthy');
        }
        
    } catch (error) {
        logToState(`Failed to initialize replica set: ${error.message}`, 'error');
        throw error;
    }
}

// Test data generation
async function generateDummyData() {
    updateInstallationStatus('testing', 97, 'Generating test data');
    
    const pythonScript = `#!/usr/bin/env python3
import json
import random
from datetime import datetime, timedelta
from pymongo import MongoClient
import base64
from PIL import Image, ImageDraw, ImageFont
import io

try:
    client = MongoClient('mongodb://${CONFIG.NODES[0]}:${CONFIG.MONGODB_PORT}/hrmlabs')
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
    
    # Generate positions
    positions = [
        {"_id": "pos_001", "title": "Software Engineer", "department_id": "dept_002", "salary_min": 8000000, "salary_max": 15000000},
        {"_id": "pos_002", "title": "HR Manager", "department_id": "dept_001", "salary_min": 12000000, "salary_max": 20000000},
        {"_id": "pos_003", "title": "Financial Analyst", "department_id": "dept_003", "salary_min": 7000000, "salary_max": 12000000},
        {"_id": "pos_004", "title": "Marketing Specialist", "department_id": "dept_004", "salary_min": 6000000, "salary_max": 10000000},
        {"_id": "pos_005", "title": "Operations Manager", "department_id": "dept_005", "salary_min": 10000000, "salary_max": 18000000}
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
            "position_id": random.choice(positions)["_id"],
            "department_id": random.choice(departments)["_id"],
            "company_id": random.choice(companies)["_id"],
            "salary": random.randint(5000000, 20000000),
            "status": random.choice(["active", "inactive"]),
            "address": f"Jl. Karyawan No. {i+1}, Jakarta",
            "birth_date": datetime(1985 + random.randint(0, 15), random.randint(1, 12), random.randint(1, 28))
        }
        employees.append(employee)
    
    # Insert data
    print("Inserting companies...")
    db.companies.insert_many(companies)
    
    print("Inserting departments...")
    db.departments.insert_many(departments)
    
    print("Inserting positions...")
    db.positions.insert_many(positions)
    
    print("Inserting employees...")
    db.employees.insert_many(employees)
    
    print(f"Data insertion completed! Inserted {len(employees)} employees.")
    
except Exception as e:
    print(f"Error: {e}")
    exit(1)
finally:
    client.close()
`;

    try {
        // Install Python dependencies
        await executeCommand('pip3 install pymongo pillow');
        
        // Write and execute Python script
        await fs.writeFile('/tmp/generate_data.py', pythonScript);
        const result = await executeCommand('python3 /tmp/generate_data.py');
        
        if (result.code !== 0) {
            throw new Error(`Data generation failed: ${result.stderr}`);
        }
        
        logToState('Test data generated successfully');
        
        // Clean up
        await fs.unlink('/tmp/generate_data.py').catch(() => {});
        
    } catch (error) {
        logToState(`Failed to generate test data: ${error.message}`, 'error');
        throw error;
    }
}

// Main installation function
async function performFullInstallation() {
    try {
        updateInstallationStatus('installing', 0, 'Starting installation');
        
        await installLocalDependencies();
        await setupMongoRepository();
        await checkSSHConnectivity();
        await initializeSSHConnections();
        await installMongoDBOnNodes();
        await configureReplication();
        await initializeReplicaSet();
        await initializeMongoConnections();
        await generateDummyData();
        
        updateInstallationStatus('completed', 100, 'Installation completed successfully');
        logToState('Full installation completed successfully!');
        
        // Start monitoring
        startSystemMonitoring();
        
    } catch (error) {
        updateInstallationStatus('error', 0, `Installation failed: ${error.message}`);
        logToState(`Installation failed: ${error.message}`, 'error');
        throw error;
    }
}

// System monitoring
function startSystemMonitoring() {
    // Update replica set status every 10 seconds
    setInterval(async () => {
        try {
            const status = await getReplicaSetStatus();
            if (status) {
                io.emit('replication-status', status);
            }
        } catch (error) {
            logger.error('Error in system monitoring:', error);
        }
    }, 10000);
    
    // Update node stats every 30 seconds
    setInterval(async () => {
        const nodeStats = {};
        for (const node of CONFIG.NODES) {
            try {
                const ssh = state.sshClients[node];
                if (ssh) {
                    const cpuResult = await ssh.execCommand("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1");
                    const memResult = await ssh.execCommand("free | grep Mem | awk '{printf \"%.1f\", $3/$2 * 100.0}'");
                    const diskResult = await ssh.execCommand("df -h / | awk 'NR==2{printf \"%s\", $5}'");
                    
                    nodeStats[node] = {
                        cpu: parseFloat(cpuResult.stdout) || 0,
                        memory: parseFloat(memResult.stdout) || 0,
                        disk: diskResult.stdout || '0%',
                        timestamp: new Date().toISOString()
                    };
                }
            } catch (error) {
                nodeStats[node] = { error: error.message };
            }
        }
        state.systemStats.nodeStats = nodeStats;
        io.emit('node-stats', nodeStats);
    }, 30000);
}

// Utility function for executing local commands
function executeCommand(command) {
    return new Promise((resolve) => {
        const process = spawn('bash', ['-c', command]);
        let stdout = '';
        let stderr = '';
        
        process.stdout.on('data', (data) => {
            stdout += data.toString();
        });
        
        process.stderr.on('data', (data) => {
            stderr += data.toString();
        });
        
        process.on('close', (code) => {
            resolve({ code, stdout, stderr });
        });
    });
}

// Terminal management for web SSH
const createTerminal = (nodeId) => {
    const terminalId = uuidv4();
    const node = CONFIG.NODES.find(n => n.includes(nodeId)) || CONFIG.NODES[0];
    
    const terminal = pty.spawn('ssh', ['-o', 'StrictHostKeyChecking=no', `${CONFIG.SSH_USER}@${node}`], {
        name: 'xterm-color',
        cols: 80,
        rows: 24,
        cwd: process.env.HOME,
        env: process.env
    });
    
    state.terminals[terminalId] = {
        terminal,
        node,
        created: new Date()
    };
    
    return terminalId;
};

// API Routes
app.get('/api/status', async (req, res) => {
    try {
        const status = await getReplicaSetStatus();
        res.json({
            success: true,
            data: status,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.get('/api/installation-status', (req, res) => {
    res.json({
        success: true,
        data: state.installationStatus
    });
});

app.post('/api/install', async (req, res) => {
    try {
        if (state.installationStatus.phase === 'installing' || state.installationStatus.phase === 'configuring') {
            return res.status(400).json({
                success: false,
                error: 'Installation already in progress'
            });
        }
        
        // Start installation in background
        performFullInstallation().catch(error => {
            logger.error('Installation error:', error);
        });
        
        res.json({
            success: true,
            message: 'Installation started'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.get('/api/nodes', async (req, res) => {
    try {
        const nodes = [];
        for (const node of CONFIG.NODES) {
            const isMongoConnected = !!state.mongoClients[node];
            const isSSHConnected = !!state.sshClients[node];
            const stats = state.systemStats.nodeStats[node] || {};
            
            nodes.push({
                name: node,
                mongoConnected: isMongoConnected,
                sshConnected: isSSHConnected,
                stats,
                lastUpdated: state.systemStats.lastUpdated
            });
        }
        res.json({
            success: true,
            data: nodes
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.get('/api/logs/:node', async (req, res) => {
    try {
        const { node } = req.params;
        const { lines = 100, follow = false } = req.query;
        
        if (!CONFIG.NODES.includes(node)) {
            return res.status(400).json({
                success: false,
                error: 'Invalid node'
            });
        }
        
        const logs = await getMongoLogs(node, parseInt(lines));
        res.json({
            success: true,
            data: {
                node,
                logs,
                timestamp: new Date().toISOString()
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.post('/api/query', async (req, res) => {
    try {
        const { node, database = 'hrmlabs', query } = req.body;
        
        if (!CONFIG.NODES.includes(node)) {
            return res.status(400).json({
                success: false,
                error: 'Invalid node'
            });
        }
        
        if (!query) {
            return res.status(400).json({
                success: false,
                error: 'Query is required'
            });
        }
        
        const result = await executeMongoQuery(node, database, query);
        res.json({
            success: true,
            data: result,
            query,
            node,
            database,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.post('/api/ssh', async (req, res) => {
    try {
        const { node, command } = req.body;
        
        if (!CONFIG.NODES.includes(node)) {
            return res.status(400).json({
                success: false,
                error: 'Invalid node'
            });
        }
        
        if (!command) {
            return res.status(400).json({
                success: false,
                error: 'Command is required'
            });
        }
        
        const result = await executeSSHCommand(node, command);
        res.json({
            success: true,
            data: result
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.post('/api/generate-test-data', async (req, res) => {
    try {
        const { recordCount = 100, includeFiles = true } = req.body;
        
        // Generate test data in background
        generateDummyData().then(() => {
            io.emit('test-data-generated', { 
                success: true, 
                recordCount,
                timestamp: new Date().toISOString()
            });
        }).catch(error => {
            io.emit('test-data-generated', { 
                success: false, 
                error: error.message 
            });
        });
        
        res.json({
            success: true,
            message: 'Test data generation started'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.post('/api/terminal', (req, res) => {
    try {
        const { nodeId } = req.body;
        const terminalId = createTerminal(nodeId);
        res.json({
            success: true,
            data: { terminalId }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// WebSocket for terminal
const wss = new WebSocket.Server({ server, path: '/terminal' });

wss.on('connection', (ws, req) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const terminalId = url.searchParams.get('terminalId');
    
    if (!terminalId || !state.terminals[terminalId]) {
        ws.close();
        return;
    }
    
    const { terminal } = state.terminals[terminalId];
    
    terminal.on('data', (data) => {
        ws.send(data);
    });
    
    ws.on('message', (data) => {
        terminal.write(data.toString());
    });
    
    ws.on('close', () => {
        if (state.terminals[terminalId]) {
            state.terminals[terminalId].terminal.kill();
            delete state.terminals[terminalId];
        }
    });
});

// Socket.IO for real-time updates
io.on('connection', (socket) => {
    logger.info('Client connected to dashboard');
    
    // Send current status
    socket.emit('installation-status', state.installationStatus);
    
    if (state.systemStats.replicationStatus) {
        socket.emit('replication-status', state.systemStats.replicationStatus);
    }
    
    if (Object.keys(state.systemStats.nodeStats).length > 0) {
        socket.emit('node-stats', state.systemStats.nodeStats);
    }
    
    socket.on('disconnect', () => {
        logger.info('Client disconnected from dashboard');
    });
    
    // Handle live log streaming
    socket.on('subscribe-logs', async (data) => {
        const { node } = data;
        if (CONFIG.NODES.includes(node)) {
            const logs = await getMongoLogs(node, 50);
            socket.emit('live-logs', { node, logs });
        }
    });
});

// Serve static files
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: '2.0.0'
    });
});

// Error handling middleware
app.use((error, req, res, next) => {
    logger.error('Express error:', error);
    res.status(500).json({
        success: false,
        error: process.env.NODE_ENV === 'production' ? 'Internal server error' : error.message
    });
});

// Start server
async function startServer() {
    try {
        // Try to initialize existing connections
        await initializeMongoConnections().catch(() => {
            logger.info('MongoDB connections will be initialized after installation');
        });
        
        await initializeSSHConnections().catch(() => {
            logger.info('SSH connections will be initialized after installation');
        });
        
        // Start monitoring if connections exist
        if (Object.keys(state.mongoClients).length > 0) {
            startSystemMonitoring();
        }
        
        server.listen(CONFIG.WEB_PORT, () => {
            logger.info(`HRM Labs MongoDB Dashboard v2.0 running on port ${CONFIG.WEB_PORT}`);
            logger.info(`Access the dashboard at: http://localhost:${CONFIG.WEB_PORT}`);
            console.log(`🚀 HRM Labs MongoDB Dashboard v2.0 is running!`);
            console.log(`📊 Dashboard: http://localhost:${CONFIG.WEB_PORT}`);
            console.log(`🔧 Health Check: http://localhost:${CONFIG.WEB_PORT}/health`);
        });
        
    } catch (error) {
        logger.error('Failed to start server:', error);
        process.exit(1);
    }
}

// Graceful shutdown
process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    server.close(() => {
        // Close MongoDB connections
        Object.values(state.mongoClients).forEach(client => {
            client.close().catch(err => logger.error('Error closing MongoDB client:', err));
        });
        
        // Close SSH connections
        Object.values(state.sshClients).forEach(ssh => {
            ssh.dispose();
        });
        
        // Close terminals
        Object.values(state.terminals).forEach(({ terminal }) => {
            terminal.kill();
        });
        
        process.exit(0);
    });
});

startServer().catch(error => {
    logger.error('Startup error:', error);
    process.exit(1);
});