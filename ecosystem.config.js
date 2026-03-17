// PM2 Ecosystem Config
// Manages all apps on the Dealer Addendums platform
// To add a new app, copy one of the existing entries and adjust name, script, and PORT

module.exports = {
  apps: [
    {
      name: 'homepage',
      script: 'apps/homepage/server/index.js',
      cwd: '/var/www/dealeraddendums-platform',
      env: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '200M',
      error_file: 'logs/homepage-err.log',
      out_file: 'logs/homepage-out.log'
    },
    {
      name: 'staterules',
      script: 'apps/staterules/server/index.js',
      cwd: '/var/www/dealeraddendums-platform',
      env: {
        NODE_ENV: 'production',
        PORT: 3001
        // ANTHROPIC_API_KEY is set via: pm2 set dealer-platform:ANTHROPIC_API_KEY sk-ant-xxx
        // then accessed below as process.env.ANTHROPIC_API_KEY
      },
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '300M',
      error_file: 'logs/staterules-err.log',
      out_file: 'logs/staterules-out.log'
    }
    {
      name: 'printersupport',
      script: 'apps/printersupport/server/index.js',
      cwd: '/var/www/dealeraddendums-platform',
      env: { NODE_ENV: 'production', PORT: 3002 },
      instances: 1, autorestart: true, watch: false,
      error_file: 'logs/printersupport-err.log',
      out_file: 'logs/printersupport-out.log'
    },
    // ── Add new apps here ──────────────────────────────────────────────────────
    // {
    //   name: 'myapp',
    //   script: 'apps/myapp/server/index.js',
    //   cwd: '/var/www/dealeraddendums-platform',
    //   env: { NODE_ENV: 'production', PORT: 3002 },
    //   instances: 1, autorestart: true, watch: false,
    //   error_file: 'logs/myapp-err.log',
    //   out_file: 'logs/myapp-out.log'
    // },
  ]
};
