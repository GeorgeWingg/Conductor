/**
 * Simple test runner for basic functionality testing
 */

const http = require('http');
const { spawn } = require('child_process');
const path = require('path');

class TestRunner {
    constructor() {
        this.tests = [];
        this.passed = 0;
        this.failed = 0;
        this.serverProcess = null;
        this.serverUrl = 'http://localhost:3001';
    }

    /**
     * Add a test case
     */
    test(name, testFn) {
        this.tests.push({ name, testFn });
    }

    /**
     * Run all tests
     */
    async run() {
        console.log('🧪 Starting Conductor Backend Tests\\n');

        try {
            // Start server in test mode
            await this.startTestServer();
            await this.waitForServer();

            // Run tests
            for (const { name, testFn } of this.tests) {
                try {
                    console.log(`  Testing: ${name}`);
                    await testFn();
                    this.passed++;
                    console.log(`  ✅ ${name}`);
                } catch (error) {
                    this.failed++;
                    console.log(`  ❌ ${name}: ${error.message}`);
                }
            }

            // Cleanup
            await this.stopTestServer();

            // Results
            console.log(`\\n📊 Test Results:`);
            console.log(`  Passed: ${this.passed}`);
            console.log(`  Failed: ${this.failed}`);
            console.log(`  Total: ${this.tests.length}`);

            if (this.failed > 0) {
                console.log(`\\n❌ Some tests failed`);
                process.exit(1);
            } else {
                console.log(`\\n✅ All tests passed!`);
                process.exit(0);
            }
        } catch (error) {
            console.error('Test runner error:', error);
            await this.stopTestServer();
            process.exit(1);
        }
    }

    /**
     * Start test server
     */
    async startTestServer() {
        return new Promise((resolve, reject) => {
            const serverPath = path.join(__dirname, '../src/server.js');
            
            this.serverProcess = spawn('node', [serverPath], {
                env: {
                    ...process.env,
                    NODE_ENV: 'test',
                    PORT: '3001',
                    MOCK_CODEX: 'true',
                    DB_PATH: ':memory:'
                },
                stdio: ['ignore', 'pipe', 'pipe']
            });

            this.serverProcess.stdout.on('data', (data) => {
                const output = data.toString();
                if (output.includes('Conductor Backend running')) {
                    resolve();
                }
            });

            this.serverProcess.stderr.on('data', (data) => {
                console.error('Server error:', data.toString());
            });

            this.serverProcess.on('error', reject);

            // Timeout after 10 seconds
            setTimeout(() => {
                reject(new Error('Server start timeout'));
            }, 10000);
        });
    }

    /**
     * Wait for server to be ready
     */
    async waitForServer(retries = 10) {
        for (let i = 0; i < retries; i++) {
            try {
                await this.makeRequest('GET', '/health');
                return;
            } catch (error) {
                if (i === retries - 1) throw error;
                await new Promise(resolve => setTimeout(resolve, 500));
            }
        }
    }

    /**
     * Stop test server
     */
    async stopTestServer() {
        if (this.serverProcess) {
            this.serverProcess.kill('SIGTERM');
            this.serverProcess = null;
        }
    }

    /**
     * Make HTTP request to server
     */
    async makeRequest(method, path, data = null) {
        return new Promise((resolve, reject) => {
            const options = {
                hostname: 'localhost',
                port: 3001,
                path,
                method,
                headers: {
                    'Content-Type': 'application/json'
                }
            };

            const req = http.request(options, (res) => {
                let body = '';
                
                res.on('data', (chunk) => {
                    body += chunk;
                });

                res.on('end', () => {
                    try {
                        const response = {
                            statusCode: res.statusCode,
                            headers: res.headers,
                            body: body ? JSON.parse(body) : null
                        };
                        resolve(response);
                    } catch (error) {
                        reject(new Error(`Invalid JSON response: ${body}`));
                    }
                });
            });

            req.on('error', reject);

            if (data) {
                req.write(JSON.stringify(data));
            }

            req.end();
        });
    }

    /**
     * Assert helper
     */
    assert(condition, message) {
        if (!condition) {
            throw new Error(message || 'Assertion failed');
        }
    }

    /**
     * Assert equal helper
     */
    assertEqual(actual, expected, message) {
        if (actual !== expected) {
            throw new Error(message || `Expected ${expected}, got ${actual}`);
        }
    }
}

// Test suite
const runner = new TestRunner();

runner.test('Health check endpoint', async () => {
    const response = await runner.makeRequest('GET', '/health');
    runner.assertEqual(response.statusCode, 200);
    runner.assert(response.body.success, 'Health check should be successful');
    runner.assert(response.body.status === 'healthy', 'Server should be healthy');
});

runner.test('Get empty tasks list', async () => {
    const response = await runner.makeRequest('GET', '/api/tasks');
    runner.assertEqual(response.statusCode, 200);
    runner.assert(response.body.success, 'Tasks request should be successful');
    runner.assert(Array.isArray(response.body.data), 'Tasks should be an array');
    runner.assertEqual(response.body.count, 0, 'Should start with no tasks');
});

runner.test('Create new task', async () => {
    const taskData = {
        prompt: 'Test task for unit testing',
        approvalMode: 'suggest'
    };

    const response = await runner.makeRequest('POST', '/api/tasks', taskData);
    runner.assertEqual(response.statusCode, 201);
    runner.assert(response.body.success, 'Task creation should be successful');
    runner.assert(response.body.data.taskId, 'Should return task ID');
    runner.assertEqual(response.body.data.prompt, taskData.prompt);
});

runner.test('Get task after creation', async () => {
    // First create a task
    const taskData = {
        prompt: 'Another test task',
        approvalMode: 'auto-edit'
    };

    const createResponse = await runner.makeRequest('POST', '/api/tasks', taskData);
    const taskId = createResponse.body.data.taskId;

    // Then get it
    const response = await runner.makeRequest('GET', `/api/tasks/${taskId}`);
    runner.assertEqual(response.statusCode, 200);
    runner.assert(response.body.success, 'Get task should be successful');
    runner.assertEqual(response.body.data.id, taskId);
    runner.assertEqual(response.body.data.prompt, taskData.prompt);
});

runner.test('Invalid task creation', async () => {
    const response = await runner.makeRequest('POST', '/api/tasks', {});
    runner.assertEqual(response.statusCode, 400);
    runner.assert(!response.body.success, 'Should fail without prompt');
    runner.assert(response.body.error.includes('Prompt is required'));
});

runner.test('System status endpoint', async () => {
    const response = await runner.makeRequest('GET', '/api/system/status');
    runner.assertEqual(response.statusCode, 200);
    runner.assert(response.body.success, 'System status should be successful');
    runner.assert(response.body.data.codex, 'Should have Codex status');
    runner.assert(response.body.data.tasks, 'Should have task stats');
});

runner.test('WebSocket stats endpoint', async () => {
    const response = await runner.makeRequest('GET', '/api/websocket/stats');
    runner.assertEqual(response.statusCode, 200);
    runner.assert(response.body.success, 'WebSocket stats should be successful');
    runner.assert(typeof response.body.data.connectedClients === 'number');
});

runner.test('404 handling', async () => {
    const response = await runner.makeRequest('GET', '/api/nonexistent');
    runner.assertEqual(response.statusCode, 404);
    runner.assert(!response.body.success, 'Should fail for nonexistent endpoint');
});

// Run tests
if (require.main === module) {
    runner.run().catch(error => {
        console.error('Test runner failed:', error);
        process.exit(1);
    });
}

module.exports = TestRunner;