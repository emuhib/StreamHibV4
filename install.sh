#!/bin/bash

# StreamHibV4 Installation Script
# Automated installation for Debian/Ubuntu servers

set -e

echo "🚀 StreamHibV4 Installation Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo"
    exit 1
fi

# Get server IP
print_status "Detecting server IP address..."
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

if [ -z "$SERVER_IP" ]; then
    SERVER_IP="localhost"
    print_warning "Could not detect external IP, using localhost"
else
    print_status "Detected server IP: $SERVER_IP"
fi

print_header "Starting StreamHibV4 installation on server: $SERVER_IP"

# Update system
print_header "Updating system packages..."
apt update && apt upgrade -y

# Install required packages including Python3 and pip for gdown
print_header "Installing required packages..."
apt install -y curl wget git ffmpeg postgresql postgresql-contrib nginx ufw python3 python3-pip

# Install Node.js 18.x
print_header "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Install gdown for Google Drive downloads
print_header "Installing gdown for Google Drive downloads..."
pip3 install gdown

# Verify installations
print_status "Verifying installations..."
node_version=$(node --version)
npm_version=$(npm --version)
ffmpeg_version=$(ffmpeg -version | head -n1 | cut -d' ' -f3)
psql_version=$(psql --version | cut -d' ' -f3)
python_version=$(python3 --version)
gdown_version=$(gdown --version 2>/dev/null || echo "installed")

print_status "✓ Node.js: $node_version"
print_status "✓ NPM: $npm_version"
print_status "✓ FFmpeg: $ffmpeg_version"
print_status "✓ PostgreSQL: $psql_version"
print_status "✓ Python3: $python_version"
print_status "✓ gdown: $gdown_version"

# Configure PostgreSQL
print_header "Configuring PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Generate secure database password
DB_PASSWORD=$(openssl rand -base64 32)

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE streamhib_v4;
CREATE USER streamhib WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE streamhib_v4 TO streamhib;
ALTER USER streamhib CREATEDB;
\q
EOF

print_status "✓ Database 'streamhib_v4' created with user 'streamhib'"

# Create application directory
print_header "Setting up application directory..."
cd /root

if [ -d "StreamHibV4" ]; then
    print_warning "StreamHibV4 directory already exists, backing up..."
    mv StreamHibV4 StreamHibV4.backup.$(date +%Y%m%d_%H%M%S)
fi

# Clone repository
print_status "Cloning StreamHibV4 repository..."
git clone https://github.com/emuhib/StreamHibV4.git
cd StreamHibV4

# Create necessary directories
mkdir -p videos videos/thumbnails logs static

# Install Node.js dependencies
print_header "Installing Node.js dependencies..."
npm install

# Create environment file
print_header "Creating environment configuration..."
cat > .env << EOF
# StreamHibV4 Environment Configuration

# Application
NODE_ENV=production
PORT=5000
# BASE_URL will be auto-detected

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=streamhib_v4
DB_USER=streamhib
DB_PASSWORD=$DB_PASSWORD

# Security
JWT_SECRET=$(openssl rand -base64 64)

# Email Configuration (configure these for password reset functionality)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM=your-email@gmail.com

# Logging
LOG_LEVEL=info
EOF

print_status "✓ Environment file created with secure credentials"

# Set permissions
print_header "Setting file permissions..."
chown -R root:root /root/StreamHibV4
chmod -R 755 /root/StreamHibV4
chmod 600 /root/StreamHibV4/.env

# Create systemd service
print_header "Creating systemd service..."
cat > /etc/systemd/system/streamhib-v4.service << EOF
[Unit]
Description=StreamHibV4 Node.js Service
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/StreamHibV4
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create FFmpeg systemd template
print_status "Creating FFmpeg systemd template..."
cat > /etc/systemd/system/streamhib-stream@.service << EOF
[Unit]
Description=StreamHib Live Stream - %i
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ffmpeg -re -stream_loop -1 -i "%i" -c:v libx264 -preset veryfast -maxrate 3000k -bufsize 6000k -pix_fmt yuv420p -g 50 -c:a aac -b:a 160k -ac 2 -ar 44100 -f flv "%i"
Restart=always
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable streamhib-v4.service

# Configure firewall
print_header "Configuring firewall..."
ufw allow 22/tcp
ufw allow 5000/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

# Configure Nginx (optional reverse proxy)
print_header "Configuring Nginx reverse proxy..."
cat > /etc/nginx/sites-available/streamhib-v4 << EOF
server {
    listen 80;
    server_name $SERVER_IP;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -sf /etc/nginx/sites-available/streamhib-v4 /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Run database migration (if old JSON files exist)
print_header "Checking for data migration..."
if [ -f "/root/StreamHibV4/sessions.json" ] || [ -f "/root/StreamHibV4/users.json" ]; then
    print_status "Found existing data files, running migration..."
    node scripts/migrate.js
    print_status "✓ Migration completed"
else
    print_status "No existing data files found, skipping migration"
fi

# Start the service
print_header "Starting StreamHibV4 service..."
systemctl start streamhib-v4.service

# Wait for service to start
print_status "Waiting for service to initialize..."
sleep 10

# Check service status
if systemctl is-active --quiet streamhib-v4.service; then
    print_status "✓ StreamHibV4 service is running successfully!"
else
    print_error "StreamHibV4 service failed to start. Check logs with: journalctl -u streamhib-v4.service -f"
    exit 1
fi

# Final status and instructions
echo ""
echo "🎉 StreamHibV4 Installation Complete!"
echo "====================================="
echo ""
print_status "🌐 Application URL: http://$SERVER_IP:5000"
print_status "📧 First-time setup: Create your admin account when you first visit the URL"
echo ""
print_header "📋 Service Management Commands:"
echo "  Start:   systemctl start streamhib-v4.service"
echo "  Stop:    systemctl stop streamhib-v4.service"
echo "  Restart: systemctl restart streamhib-v4.service"
echo "  Status:  systemctl status streamhib-v4.service"
echo "  Logs:    journalctl -u streamhib-v4.service -f"
echo ""
print_header "🗄️ Database Information:"
echo "  Database: streamhib_v4"
echo "  User: streamhib"
echo "  Password: $DB_PASSWORD"
echo ""
print_header "📁 Application Directory:"
echo "  Location: /root/StreamHibV4"
echo "  Videos: /root/StreamHibV4/videos"
echo "  Logs: /root/StreamHibV4/logs"
echo ""
print_warning "📧 Important: Configure email settings in /root/StreamHibV4/.env for password reset functionality"
echo ""
print_status "🚀 Installation completed successfully!"
print_status "🎯 Visit http://$SERVER_IP:5000 to create your admin account and start streaming!"
echo ""