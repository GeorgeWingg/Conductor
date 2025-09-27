#!/usr/bin/env node

/**
 * Setup script for Conductor Backend
 * Configures environment and checks dependencies
 */

const fs = require('fs').promises;
const path = require('path');
const { spawn } = require('child_process');
const PlatformUtils = require('../src/utils/platform');

class SetupScript {
    constructor() {
        this.rootDir = path.dirname(__dirname);
        this.envPath = path.join(this.rootDir, '.env');
        this.errors = [];
        this.warnings = [];
    }

    async run() {
        console.log('🔧 Setting up Conductor Backend\\n');

        try {
            await this.checkNodeVersion();
            await this.createEnvironmentFile();
            await this.createDataDirectories();
            await this.checkCodexCLI();
            await this.testDatabaseConnection();
            await this.runBasicTests();
            
            this.printResults();
            
            if (this.errors.length === 0) {
                console.log('\\n🎉 Setup completed successfully!');
                console.log('\\n🚀 You can now start the server with: npm run dev');
            } else {
                console.log('\\n❌ Setup completed with errors. Please fix them before starting the server.');
                process.exit(1);
            }
        } catch (error) {
            console.error('\\n💥 Setup failed:', error.message);
            process.exit(1);
        }
    }

    async checkNodeVersion() {
        const nodeVersion = process.version;
        const majorVersion = parseInt(nodeVersion.slice(1).split('.')[0]);
        
        if (majorVersion < 18) {
            this.errors.push(`Node.js ${nodeVersion} is too old. Please upgrade to Node.js 18 or higher.`);
        } else {
            console.log(`✅ Node.js ${nodeVersion} is compatible`);
        }
    }

    async createEnvironmentFile() {
        try {
            await fs.access(this.envPath);
            console.log('✅ .env file already exists');
        } catch (error) {
            // .env doesn't exist, create it from template
            try {
                const examplePath = path.join(this.rootDir, '.env.example');
                const exampleContent = await fs.readFile(examplePath, 'utf8');
                await fs.writeFile(this.envPath, exampleContent);
                console.log('✅ Created .env file from template');
                this.warnings.push('Please update .env file with your configuration');
            } catch (createError) {
                this.errors.push('Failed to create .env file');
            }
        }
    }

    async createDataDirectories() {
        const directories = [
            path.join(this.rootDir, 'data'),
            path.join(this.rootDir, 'data', 'sessions'),
            path.join(this.rootDir, 'logs')
        ];

        for (const dir of directories) {
            try {
                await fs.mkdir(dir, { recursive: true });
                console.log(`✅ Created directory: ${path.relative(this.rootDir, dir)}`);
            } catch (error) {
                this.errors.push(`Failed to create directory: ${dir}`);
            }
        }
    }

    async checkCodexCLI() {
        return new Promise((resolve) => {
            const codexCommand = PlatformUtils.getCodexCommand();
            
            const checkProcess = spawn(codexCommand, ['--version'], {
                stdio: ['ignore', 'pipe', 'pipe']
            });

            let output = '';
            checkProcess.stdout.on('data', (data) => {
                output += data.toString();
            });

            checkProcess.on('close', (code) => {
                if (code === 0) {
                    console.log(`✅ Codex CLI is available: ${output.trim()}`);
                } else {
                    this.warnings.push('Codex CLI not found - Mock mode will be used');
                    console.log('⚠️  Codex CLI not found, enabling mock mode');
                }
                resolve();
            });

            checkProcess.on('error', () => {
                this.warnings.push('Codex CLI not found - Mock mode will be used');
                console.log('⚠️  Codex CLI not found, enabling mock mode');
                resolve();
            });
        });
    }

    async testDatabaseConnection() {
        try {
            const DatabaseService = require('../src/services/database');
            const dbService = new DatabaseService({
                dbPath: path.join(this.rootDir, 'data', 'test-setup.db')
            });

            await dbService.initialize();
            await dbService.close();
            
            // Clean up test database
            try {
                await fs.unlink(path.join(this.rootDir, 'data', 'test-setup.db'));
            } catch (e) {
                // Ignore cleanup errors
            }

            console.log('✅ Database connection test passed');
        } catch (error) {
            this.errors.push(`Database test failed: ${error.message}`);
        }
    }

    async runBasicTests() {
        try {
            console.log('🧪 Running basic functionality tests...');
            
            // Test platform utilities
            const debugInfo = PlatformUtils.debugEnvironment();
            console.log(`   Platform: ${debugInfo.platform}`);
            console.log(`   Node: ${debugInfo.nodeVersion}`);
            console.log(`   Home: ${debugInfo.homeDirectory}`);
            
            // Test path sanitization
            try {
                const testPath = path.join(debugInfo.homeDirectory, 'Desktop');
                PlatformUtils.sanitizePath(testPath);
                console.log('✅ Path sanitization working');
            } catch (e) {
                this.errors.push(`Path sanitization failed: ${e.message}`);
            }

            console.log('✅ Basic tests passed');
        } catch (error) {
            this.warnings.push(`Basic tests had issues: ${error.message}`);
        }
    }

    printResults() {
        console.log('\\n📋 Setup Summary:');
        
        if (this.warnings.length > 0) {
            console.log('\\n⚠️  Warnings:');
            this.warnings.forEach(warning => {
                console.log(`   • ${warning}`);
            });
        }

        if (this.errors.length > 0) {
            console.log('\\n❌ Errors:');
            this.errors.forEach(error => {
                console.log(`   • ${error}`);
            });
        }
    }
}

// Run setup if called directly
if (require.main === module) {
    const setup = new SetupScript();
    setup.run().catch(error => {
        console.error('Setup script failed:', error);
        process.exit(1);
    });
}

module.exports = SetupScript;