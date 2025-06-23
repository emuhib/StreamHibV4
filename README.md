# StreamHibV4 - Node.js Live Streaming Platform

> **Release Date**: 31/05/2025  
> **Status**: Complete Node.js Migration with PostgreSQL  
> **Function**: Live streaming management platform based on Node.js + FFmpeg, suitable for VPS servers worldwide.

---

## ✨ Key Features

* **Modern Node.js Backend** with Express.js and Socket.IO
* **PostgreSQL Database** for robust data storage and integrity
* **FFmpeg Integration** with systemd service management
* **Email-based Authentication** with password recovery
* **Automated Installation** - one command setup
* **Video Management** with thumbnail generation and Google Drive downloads
* **Live Session Management** with real-time updates
* **Advanced Scheduling System** with timezone support
* **Responsive Web Interface** with Alpine.js and Tailwind CSS

---

## 🚀 Quick Installation

### One-Command Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/emuhib/StreamHibV4/main/install.sh | sudo bash
```

This will automatically:
- Install all dependencies (Node.js, PostgreSQL, FFmpeg, Python3, gdown, etc.)
- Configure the database
- Set up systemd services
- Start the application
- Display the access URL

---

## 📋 Prerequisites

* **Operating System**: Debian/Ubuntu-based VPS
* **Access**: Root privileges or sudo access
* **Ports**: 5000 (application), 80/443 (optional nginx proxy)
* **Memory**: Minimum 1GB RAM recommended
* **Storage**: At least 10GB free space for videos

---

## 🛠 Manual Installation

If you prefer manual installation:

### 1. System Update & Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git ffmpeg postgresql postgresql-contrib nginx ufw python3 python3-pip

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install gdown for Google Drive downloads
pip3 install gdown
```

### 2. Database Setup

```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE streamhib_v4;
CREATE USER streamhib WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE streamhib_v4 TO streamhib;
ALTER USER streamhib CREATEDB;
\q
EOF
```

### 3. Application Setup

```bash
# Clone repository
cd /root
git clone https://github.com/emuhib/StreamHibV4.git
cd StreamHibV4

# Install dependencies
npm install

# Configure environment
cp .env.example .env
nano .env
```

### 4. Environment Configuration

Edit `.env` file:

```env
NODE_ENV=production
PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=streamhib_v4
DB_USER=streamhib
DB_PASSWORD=your_secure_password
JWT_SECRET=your_jwt_secret_key

# Email configuration (for password reset)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM=your-email@gmail.com
```

### 5. Service Configuration

```bash
# Create systemd service
sudo tee /etc/systemd/system/streamhib-v4.service > /dev/null << EOF
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

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable streamhib-v4.service
sudo systemctl start streamhib-v4.service
```

---

## 🎯 First Time Setup

1. **Access the application** in your browser: `http://your-server-ip:5000`
2. **You'll see the "Welcome to StreamHibV4" page**
3. **Create your admin account:**
   - Enter your email address
   - Set a secure password (minimum 6 characters)
   - Confirm the password
4. **Click "Create Admin Account"**
5. **You'll be automatically logged in and redirected to the dashboard**

---

## 📱 Using the Application

### Video Management
- **Upload videos** directly through the web interface
- **Download from Google Drive** using share links (fixed gdown implementation)
- **Generate thumbnails** automatically
- **Rename and organize** your video library

### Live Streaming
- **Create streaming sessions** with platform-specific settings
- **Start/stop streams** with one click
- **Monitor active streams** in real-time
- **Support for multiple platforms**: YouTube, Facebook, Twitch, Instagram, TikTok, Custom RTMP

### Scheduling
- **Schedule streams** for specific times
- **Daily recurring streams** with timezone support
- **One-time scheduled streams**
- **Automatic start/stop** based on schedule

### System Management
- **Monitor disk usage** and system resources
- **View application logs**
- **Clean up old files** and thumbnails
- **Real-time status updates**

---

## 🔧 Management Commands

### Service Management
```bash
# Check status
sudo systemctl status streamhib-v4.service

# Start service
sudo systemctl start streamhib-v4.service

# Stop service
sudo systemctl stop streamhib-v4.service

# Restart service
sudo systemctl restart streamhib-v4.service

# View logs
journalctl -u streamhib-v4.service -f
```

### Database Management
```bash
# Connect to database
sudo -u postgres psql streamhib_v4

# Backup database
sudo -u postgres pg_dump streamhib_v4 > backup.sql

# Restore database
sudo -u postgres psql streamhib_v4 < backup.sql
```

---

## 🔄 Migration from Previous Versions

If you have data from StreamHibV2 or V3:

```bash
# Run migration script
cd /root/StreamHibV4
node scripts/migrate.js
```

This will migrate:
- User accounts from JSON files
- Session configurations
- Video metadata
- Schedule settings

---

## 🛡 Security Features

- **JWT-based authentication** with secure token management
- **Password hashing** using bcrypt
- **Rate limiting** on authentication endpoints
- **CORS protection** and security headers
- **Input validation** and sanitization
- **SQL injection protection** through parameterized queries

---

## 🌐 Email Configuration

For password reset functionality, configure SMTP settings:

### Gmail Setup
1. Enable 2-factor authentication
2. Generate an App Password
3. Use the App Password in `SMTP_PASS`

### Other Providers
- **Outlook/Hotmail**: `smtp.live.com:587`
- **Yahoo**: `smtp.mail.yahoo.com:587`
- **Custom SMTP**: Configure according to your provider

---

## 🚨 Troubleshooting

### Common Issues

**Port 5000 already in use:**
```bash
sudo lsof -i :5000
sudo kill -9 <PID>
```

**Database connection failed:**
```bash
sudo systemctl status postgresql
sudo -u postgres psql -c "SELECT version();"
```

**FFmpeg not found:**
```bash
which ffmpeg
sudo apt install ffmpeg
```

**gdown not working:**
```bash
pip3 install --upgrade gdown
which gdown
```

**Permission issues:**
```bash
sudo chown -R root:root /root/StreamHibV4
sudo chmod -R 755 /root/StreamHibV4
```

### Log Locations
- **Application logs**: `/root/StreamHibV4/logs/`
- **System logs**: `journalctl -u streamhib-v4.service`
- **PostgreSQL logs**: `/var/log/postgresql/`

---

## 🆕 What's New in V4

### Complete Node.js Migration
- **100% Node.js** - No more Python dependencies for the main application
- Improved performance and scalability
- Better real-time communication with Socket.IO
- **Removed app.py** - fully migrated to server.js

### Fixed Google Drive Downloads
- **Working gdown integration** with proper error handling
- Support for multiple Google Drive URL formats
- Automatic gdown installation if missing
- Better download progress tracking

### PostgreSQL Integration
- Replaced JSON file storage with PostgreSQL
- ACID compliance and data integrity
- Better concurrent access handling
- Automatic schema initialization

### Enhanced Authentication
- Email-based login system
- Password recovery via email
- Secure JWT token management
- **First-time setup wizard** with automatic registration page

### Improved UI/UX
- **Automatic registration page** for first access
- Video thumbnail previews
- Real-time status updates
- Responsive design improvements
- Complete UI/UX from Python version preserved

### Robust Scheduling
- Persistent scheduling with database storage
- Timezone-aware scheduling
- Recovery after application restarts
- Support for daily and one-time schedules

---

## 📞 Support

For issues and support:

1. **Check the logs** first:
   ```bash
   journalctl -u streamhib-v4.service -f
   ```

2. **Common solutions** in the troubleshooting section above

3. **GitHub Issues**: [Report bugs or request features](https://github.com/emuhib/StreamHibV4/issues)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **FFmpeg** for video processing capabilities
- **PostgreSQL** for robust data storage
- **Node.js** ecosystem for excellent libraries
- **Alpine.js** and **Tailwind CSS** for the frontend

---

**StreamHibV4** - Professional live streaming management made simple! 🚀