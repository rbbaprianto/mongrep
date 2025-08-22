module.exports = {
  apps: [
    {
      name: 'hrmlabs-mongodb-dashboard',
      script: 'server.js',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      log_date_format: 'YYYY-MM-DD HH:mm Z',
      error_file: './logs/pm2-error.log',
      out_file: './logs/pm2-out.log',
      log_file: './logs/pm2-combined.log',
      time: true,
      max_restarts: 10,
      min_uptime: '10s',
      kill_timeout: 5000,
      listen_timeout: 3000,
      shutdown_with_message: true,
      wait_ready: true,
      restart_delay: 4000
    }
  ],
  
  deploy: {
    production: {
      user: 'root',
      host: ['hrmlabs-mongo-primary'],
      ref: 'origin/main',
      repo: 'git@github.com:your-repo/hrmlabs-mongo-automation.git',
      path: '/opt/hrmlabs-dashboard',
      'pre-deploy-local': '',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production',
      'pre-setup': ''
    }
  }
};