const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const cookieParser = require('cookie-parser');
const path = require('path');
const os = require('os');
require('dotenv').config();

const logger = require('./utils/logger');
const db = require('./config/database');
const authRoutes = require('./routes/auth');
const videoRoutes = require('./routes/videos');
const sessionRoutes = require('./routes/sessions');
const scheduleRoutes = require('./routes/schedules');
const systemRoutes = require('./routes/system');
const { authenticateToken } = require('./middleware/auth');
const { initializeScheduler } = require('./services/scheduler');
const { initializeSystemdServices } = require('./services/systemd');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Auto-detect server IP and set BASE_URL if not provided
if (!process.env.BASE_URL) {
  const networkInterfaces = os.networkInterfaces();
  let serverIP = 'localhost';
  
  // Try to find external IP
  for (const interfaceName in networkInterfaces) {
    const addresses = networkInterfaces[interfaceName];
    for (const address of addresses) {
      if (address.family === 'IPv4' && !address.internal) {
        serverIP = address.address;
        break;
      }
    }
    if (serverIP !== 'localhost') break;
  }
  
  const port = process.env.PORT || 5000;
  process.env.BASE_URL = `http://${serverIP}:${port}`;
  logger.info(`Auto-detected BASE_URL: ${process.env.BASE_URL}`);
}

// Security middleware
app.use(helmet({
  contentSecurityPolicy: false // Allow inline scripts for Alpine.js
}));
app.use(compression());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/auth', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5 // stricter limit for auth endpoints
}));
app.use(limiter);

// CORS and body parsing
app.use(cors({
  origin: true,
  credentials: true
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(cookieParser());

// Static files
app.use('/static', express.static(path.join(__dirname, 'static')));
app.use('/videos', express.static(path.join(__dirname, 'videos')));

// Make io available to routes
app.use((req, res, next) => {
  req.io = io;
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/videos', authenticateToken, videoRoutes);
app.use('/api/sessions', authenticateToken, sessionRoutes);
app.use('/api/schedules', authenticateToken, scheduleRoutes);
app.use('/api/system', authenticateToken, systemRoutes);

// Check if setup is needed
async function checkSetupNeeded() {
  try {
    const result = await db.query('SELECT COUNT(*) as count FROM users');
    return parseInt(result.rows[0].count) === 0;
  } catch (error) {
    logger.error('Error checking setup status:', error);
    return true; // Assume setup needed if error
  }
}

// Main page route - show register page for first-time setup
app.get('/', async (req, res) => {
  try {
    const setupNeeded = await checkSetupNeeded();
    
    if (setupNeeded) {
      // Show register page for first-time setup
      res.sendFile(path.join(__dirname, 'templates', 'register.html'));
    } else {
      // Show main app (original index.html)
      res.sendFile(path.join(__dirname, 'templates', 'index.html'));
    }
  } catch (error) {
    logger.error('Error serving main page:', error);
    res.status(500).send('Server error');
  }
});

// Logout route
app.get('/logout', (req, res) => {
  res.clearCookie('auth_token');
  res.redirect('/');
});

// Password reset page
app.get('/reset-password', (req, res) => {
  const { token } = req.query;
  if (!token) {
    return res.status(400).send('Invalid reset token');
  }
  
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Reset Password - StreamHibV4</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link rel="icon" type="image/x-icon" href="/static/favicon.ico">
    </head>
    <body class="bg-gray-50 min-h-screen flex items-center justify-center">
        <div class="bg-white rounded-lg shadow-md p-8 max-w-md w-full mx-4">
            <div class="text-center mb-6">
                <img src="/static/logostreamhib.png" alt="StreamHib Logo" class="mx-auto mb-4 h-16">
                <h2 class="text-2xl font-bold text-gray-800">Reset Password</h2>
            </div>
            <form id="resetForm">
                <div class="mb-4">
                    <label class="block text-gray-700 text-sm font-bold mb-2">New Password</label>
                    <input type="password" id="password" required minlength="6"
                           class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
                </div>
                <div class="mb-6">
                    <label class="block text-gray-700 text-sm font-bold mb-2">Confirm Password</label>
                    <input type="password" id="confirmPassword" required minlength="6"
                           class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
                </div>
                <button type="submit" class="w-full bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded-md">
                    Reset Password
                </button>
            </form>
            <div id="message" class="mt-4 p-3 rounded-md hidden"></div>
        </div>
        
        <script>
            document.getElementById('resetForm').addEventListener('submit', async (e) => {
                e.preventDefault();
                
                const password = document.getElementById('password').value;
                const confirmPassword = document.getElementById('confirmPassword').value;
                const messageDiv = document.getElementById('message');
                
                if (password !== confirmPassword) {
                    messageDiv.className = 'mt-4 p-3 rounded-md bg-red-100 text-red-700';
                    messageDiv.textContent = 'Passwords do not match';
                    messageDiv.classList.remove('hidden');
                    return;
                }
                
                try {
                    const response = await fetch('/api/auth/reset-password', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ token: '${token}', password })
                    });
                    
                    const data = await response.json();
                    
                    if (data.success) {
                        messageDiv.className = 'mt-4 p-3 rounded-md bg-green-100 text-green-700';
                        messageDiv.textContent = 'Password reset successfully! You can now login with your new password.';
                        document.getElementById('resetForm').style.display = 'none';
                    } else {
                        messageDiv.className = 'mt-4 p-3 rounded-md bg-red-100 text-red-700';
                        messageDiv.textContent = data.message;
                    }
                    
                    messageDiv.classList.remove('hidden');
                } catch (error) {
                    messageDiv.className = 'mt-4 p-3 rounded-md bg-red-100 text-red-700';
                    messageDiv.textContent = 'Failed to reset password';
                    messageDiv.classList.remove('hidden');
                }
            });
        </script>
    </body>
    </html>
  `);
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  logger.info(`Client connected: ${socket.id}`);
  
  socket.on('disconnect', () => {
    logger.info(`Client disconnected: ${socket.id}`);
  });
});

// Global error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({ 
    success: false, 
    message: 'Internal server error' 
  });
});

// Initialize services
async function initializeApp() {
  try {
    // Test database connection
    await db.query('SELECT NOW()');
    logger.info('Database connected successfully');
    
    // Initialize scheduler
    await initializeScheduler(io);
    logger.info('Scheduler initialized');
    
    // Initialize systemd services
    await initializeSystemdServices();
    logger.info('Systemd services initialized');
    
    const PORT = process.env.PORT || 5000;
    server.listen(PORT, '0.0.0.0', () => {
      logger.info(`StreamHibV4 server running on port ${PORT}`);
      logger.info(`Access URL: ${process.env.BASE_URL}`);
    });
    
  } catch (error) {
    logger.error('Failed to initialize application:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

initializeApp();

module.exports = { app, server, io };