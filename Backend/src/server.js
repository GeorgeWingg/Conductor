require('dotenv').config();

const express = require('express');
const http = require('http');
const cors = require('cors');
const morgan = require('morgan');

// Services
const CodexService = require('./services/codex');
const WebSocketService = require('./services/websocket');
const DatabaseService = require('./services/database');
const SessionMonitor = require('./services/session-monitor');

// Routes
const createTaskRoutes = require('./routes/tasks');
const createSystemRoutes = require('./routes/system');

// Middleware
const {
    createRateLimiter,
    validateApiKey,
    errorHandler,
    notFoundHandler,
    securityHeaders,
    getCorsOptions
} = require('./middleware/security');

// Platform utilities
const PlatformUtils = require('./utils/platform');

/**
 * Conductor Backend Server
 * AI-powered task management through Codex CLI
 */
class ConductorServer {
    constructor() {
        this.app = express();
        this.server = http.createServer(this.app);
        this.port = process.env.PORT || 3001;
        this.host = process.env.HOST || 'localhost';
        
        // Services
        this.codexService = null;
        this.wsService = null;
        this.dbService = null;
        this.sessionMonitor = null;
        
        this.isShuttingDown = false;
    }

    /**
     * Initialize all services and middleware
     */
    async initialize() {
        try {
            console.log('Initializing Conductor Backend...');
            
            // Debug environment in development
            if (process.env.NODE_ENV === 'development') {
                console.log('Environment:', PlatformUtils.debugEnvironment());
            }

            // Initialize database
            this.dbService = new DatabaseService({
                dbPath: process.env.DB_PATH
            });
            await this.dbService.initialize();

            // Initialize Codex service
            this.codexService = new CodexService({
                codexPath: process.env.CODEX_CLI_PATH,
                mockMode: process.env.MOCK_CODEX === 'true'
            });

            // Initialize session monitor
            this.sessionMonitor = new SessionMonitor();
            await this.sessionMonitor.startMonitoring();

            // Initialize WebSocket service
            this.wsService = new WebSocketService(this.server, {
                corsOrigins: process.env.CORS_ORIGINS?.split(',') || undefined
            });

            // Connect services
            this.connectServices();

            // Setup Express middleware
            this.setupMiddleware();

            // Setup routes
            this.setupRoutes();

            // Setup error handling
            this.setupErrorHandling();

            // Setup graceful shutdown
            this.setupGracefulShutdown();

            console.log('Backend initialization completed');
        } catch (error) {
            console.error('Failed to initialize backend:', error);
            throw error;
        }
    }

    /**
     * Connect services together
     */
    connectServices() {
        // Connect Codex service to WebSocket for real-time updates
        this.wsService.connectCodexService(this.codexService);

        // Connect Codex service to database for persistence
        this.codexService.on('taskCreated', async (data) => {
            try {
                await this.dbService.saveTask(data.task);
            } catch (error) {
                console.error('Failed to save task to database:', error);
            }
        });

        this.codexService.on('taskCompleted', async (data) => {
            try {
                await this.dbService.saveTask(data.task);
            } catch (error) {
                console.error('Failed to update task in database:', error);
            }
        });

        this.codexService.on('taskFailed', async (data) => {
            try {
                await this.dbService.saveTask(data.task);
            } catch (error) {
                console.error('Failed to update task in database:', error);
            }
        });

        this.codexService.on('taskLog', async (data) => {
            try {
                await this.dbService.saveTaskLog(data.taskId, {
                    type: data.type,
                    message: data.message,
                    timestamp: new Date()
                });
            } catch (error) {
                console.error('Failed to save task log:', error);
            }
        });

        // Connect session monitor to database
        this.sessionMonitor.on('session_discovered', async (data) => {
            try {
                const session = this.sessionMonitor.getSession(data.sessionId);
                if (session) {
                    await this.dbService.saveSession(session);
                }
            } catch (error) {
                console.error('Failed to save session to database:', error);
            }
        });
    }

    /**
     * Setup Express middleware
     */
    setupMiddleware() {
        // Security headers
        this.app.use(securityHeaders);

        // CORS
        this.app.use(cors(getCorsOptions()));

        // Request logging
        this.app.use(morgan(process.env.NODE_ENV === 'development' ? 'dev' : 'combined'));

        // Rate limiting
        this.app.use('/api/', createRateLimiter(15 * 60 * 1000, 100)); // 100 requests per 15 minutes
        this.app.use('/api/tasks', createRateLimiter(5 * 60 * 1000, 20)); // 20 task requests per 5 minutes

        // Body parsing
        this.app.use(express.json({ limit: '10mb' }));
        this.app.use(express.urlencoded({ extended: true }));

        // API key validation (skip in development unless API_SECRET is set)
        if (process.env.NODE_ENV === 'production' || process.env.API_SECRET) {
            this.app.use('/api/', validateApiKey);
        }
    }

    /**
     * Setup API routes
     */
    setupRoutes() {
        // Health check (no API prefix)
        this.app.get('/health', async (req, res) => {
            try {
                const codexStatus = await this.codexService.checkCodexAvailability();
                res.json({
                    success: true,
                    status: 'healthy',
                    timestamp: new Date().toISOString(),
                    services: {
                        codex: codexStatus.available,
                        database: !!this.dbService.db,
                        websocket: this.wsService.getStats().connectedClients >= 0,
                        sessionMonitor: this.sessionMonitor.isMonitoring
                    }
                });
            } catch (error) {
                res.status(500).json({
                    success: false,
                    status: 'unhealthy',
                    error: error.message
                });
            }
        });

        // API routes
        this.app.use('/api/tasks', createTaskRoutes(this.codexService));
        this.app.use('/api/system', createSystemRoutes(this.codexService));

        // WebSocket status endpoint
        this.app.get('/api/websocket/stats', (req, res) => {
            res.json({
                success: true,
                data: this.wsService.getStats()
            });
        });

        // Database stats endpoint
        this.app.get('/api/database/stats', async (req, res) => {
            try {
                const stats = await this.dbService.getStats();
                res.json({
                    success: true,
                    data: stats
                });
            } catch (error) {
                res.status(500).json({
                    success: false,
                    error: error.message
                });
            }
        });

        // Session monitor stats endpoint
        this.app.get('/api/sessions/stats', (req, res) => {
            res.json({
                success: true,
                data: this.sessionMonitor.getStats()
            });
        });
    }

    /**
     * Setup error handling
     */
    setupErrorHandling() {
        // 404 handler
        this.app.use(notFoundHandler);

        // Global error handler
        this.app.use(errorHandler);

        // Handle uncaught exceptions
        process.on('uncaughtException', (error) => {
            console.error('Uncaught Exception:', error);
            this.gracefulShutdown('SIGTERM');
        });

        process.on('unhandledRejection', (reason, promise) => {
            console.error('Unhandled Rejection at:', promise, 'reason:', reason);
            // Don't exit on unhandled rejection in development
            if (process.env.NODE_ENV === 'production') {
                this.gracefulShutdown('SIGTERM');
            }
        });
    }

    /**
     * Setup graceful shutdown handlers
     */
    setupGracefulShutdown() {
        const signals = ['SIGTERM', 'SIGINT', 'SIGUSR2'];
        
        signals.forEach(signal => {
            process.on(signal, () => {
                console.log(`Received ${signal}, starting graceful shutdown...`);
                this.gracefulShutdown(signal);
            });
        });
    }

    /**
     * Start the server
     */
    async start() {
        try {
            await this.initialize();
            
            this.server.listen(this.port, this.host, () => {
                console.log(`🚀 Conductor Backend running on http://${this.host}:${this.port}`);
                console.log(`📊 Health check: http://${this.host}:${this.port}/health`);
                console.log(`🔌 WebSocket: ws://${this.host}:${this.port}`);
                console.log(`📝 API Docs: http://${this.host}:${this.port}/api`);
                
                if (process.env.MOCK_CODEX === 'true') {
                    console.log('⚠️  Running in MOCK mode - Codex CLI calls will be simulated');
                }
            });

            return this.server;
        } catch (error) {
            console.error('Failed to start server:', error);
            process.exit(1);
        }
    }

    /**
     * Graceful shutdown
     */
    async gracefulShutdown(signal) {
        if (this.isShuttingDown) {
            console.log('Already shutting down...');
            return;
        }

        this.isShuttingDown = true;
        console.log(`Shutting down gracefully (${signal})...`);

        try {
            // Stop accepting new connections
            this.server.close(() => {
                console.log('HTTP server closed');
            });

            // Close WebSocket connections
            if (this.wsService) {
                this.wsService.shutdown();
            }

            // Stop session monitoring
            if (this.sessionMonitor) {
                await this.sessionMonitor.stopMonitoring();
            }

            // Close database connection
            if (this.dbService) {
                await this.dbService.close();
            }

            console.log('Graceful shutdown completed');
            process.exit(0);
        } catch (error) {
            console.error('Error during shutdown:', error);
            process.exit(1);
        }
    }
}

// Start server if this file is run directly
if (require.main === module) {
    const server = new ConductorServer();
    server.start().catch(error => {
        console.error('Failed to start Conductor Backend:', error);
        process.exit(1);
    });
}

module.exports = ConductorServer;