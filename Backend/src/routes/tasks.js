const express = require('express');
const router = express.Router();

/**
 * Task management routes
 */
function createTaskRoutes(codexService) {
    
    // GET /tasks - Get all tasks
    router.get('/', async (req, res) => {
        try {
            const tasks = codexService.getAllTasks();
            res.json({
                success: true,
                data: tasks,
                count: tasks.length
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });

    // GET /tasks/:id - Get specific task
    router.get('/:id', async (req, res) => {
        try {
            const task = codexService.getTask(req.params.id);
            if (!task) {
                return res.status(404).json({
                    success: false,
                    error: 'Task not found'
                });
            }
            
            res.json({
                success: true,
                data: task
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });

    // POST /tasks - Create new task
    router.post('/', async (req, res) => {
        try {
            const { prompt, workingDir, approvalMode } = req.body;
            
            if (!prompt) {
                return res.status(400).json({
                    success: false,
                    error: 'Prompt is required'
                });
            }

            const taskSpec = {
                prompt,
                workingDir,
                approvalMode,
                json: true
            };

            // Start task execution (non-blocking)
            codexService.executeTask(taskSpec)
                .catch(error => {
                    console.error(`Task execution failed: ${error.message}`);
                });

            // Return task ID immediately
            const tasks = codexService.getAllTasks();
            const newTask = tasks[tasks.length - 1]; // Get the most recently created task

            res.status(201).json({
                success: true,
                data: {
                    taskId: newTask.id,
                    status: newTask.status,
                    prompt: newTask.prompt
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });

    // POST /tasks/:id/approve - Approve pending task
    router.post('/:id/approve', async (req, res) => {
        try {
            const { approved = true } = req.body;
            const task = await codexService.approveTask(req.params.id, approved);
            
            res.json({
                success: true,
                data: task
            });
        } catch (error) {
            res.status(400).json({
                success: false,
                error: error.message
            });
        }
    });

    // DELETE /tasks/:id - Cancel task
    router.delete('/:id', async (req, res) => {
        try {
            const task = await codexService.cancelTask(req.params.id);
            
            res.json({
                success: true,
                data: task
            });
        } catch (error) {
            res.status(400).json({
                success: false,
                error: error.message
            });
        }
    });

    // GET /tasks/:id/logs - Get task logs
    router.get('/:id/logs', async (req, res) => {
        try {
            const task = codexService.getTask(req.params.id);
            if (!task) {
                return res.status(404).json({
                    success: false,
                    error: 'Task not found'
                });
            }
            
            res.json({
                success: true,
                data: task.logs || []
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

module.exports = createTaskRoutes;