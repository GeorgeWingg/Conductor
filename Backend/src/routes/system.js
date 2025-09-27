const express = require('express');
const router = express.Router();
const PlatformUtils = require('../utils/platform');

/**
 * System information and health check routes
 */
function createSystemRoutes(codexService) {
    
    // GET /health - Health check endpoint
    router.get('/health', async (req, res) => {
        try {
            const codexStatus = await codexService.checkCodexAvailability();
            const activeTasks = codexService.getAllTasks();
            const runningTasks = activeTasks.filter(t => t.status === 'running').length;
            
            res.json({
                success: true,
                status: 'healthy',
                timestamp: new Date().toISOString(),
                data: {
                    server: 'running',
                    codex: codexStatus,
                    tasks: {
                        total: activeTasks.length,
                        running: runningTasks,
                        active: activeTasks.filter(t => 
                            ['running', 'waiting_approval', 'starting'].includes(t.status)
                        ).length
                    },
                    platform: PlatformUtils.debugEnvironment()
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                status: 'unhealthy',
                error: error.message,
                timestamp: new Date().toISOString()
            });
        }
    });

    // GET /status - Detailed system status
    router.get('/status', async (req, res) => {
        try {
            const codexStatus = await codexService.checkCodexAvailability();
            const tasks = codexService.getAllTasks();
            
            const taskStats = {
                total: tasks.length,
                completed: tasks.filter(t => t.status === 'completed').length,
                failed: tasks.filter(t => t.status === 'failed').length,
                running: tasks.filter(t => t.status === 'running').length,
                waiting_approval: tasks.filter(t => t.status === 'waiting_approval').length,
                cancelled: tasks.filter(t => t.status === 'cancelled').length
            };

            res.json({
                success: true,
                data: {
                    codex: codexStatus,
                    tasks: taskStats,
                    platform: PlatformUtils.debugEnvironment(),
                    uptime: process.uptime(),
                    memory: process.memoryUsage(),
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

    // GET /config - Get configuration information
    router.get('/config', (req, res) => {
        try {
            res.json({
                success: true,
                data: {
                    platform: process.platform,
                    nodeVersion: process.version,
                    environment: process.env.NODE_ENV || 'development',
                    mockMode: process.env.MOCK_CODEX === 'true',
                    codexPath: PlatformUtils.getCodexCommand(),
                    configPath: PlatformUtils.getCodexConfigPath(),
                    corsEnabled: true
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });

    // POST /cleanup - Clean up old completed tasks
    router.post('/cleanup', (req, res) => {
        try {
            const { maxAge } = req.body;
            codexService.cleanupOldTasks(maxAge);
            
            res.json({
                success: true,
                message: 'Cleanup completed',
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });

    return router;
}

module.exports = createSystemRoutes;