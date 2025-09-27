const fs = require('fs').promises;
const path = require('path');
const chokidar = require('chokidar');
const { EventEmitter } = require('events');
const PlatformUtils = require('../utils/platform');

/**
 * Session monitoring service for watching Codex JSONL logs
 */
class SessionMonitor extends EventEmitter {
    constructor(options = {}) {
        super();
        this.sessionsPath = options.sessionsPath || PlatformUtils.getCodexSessionsPath();
        this.watchers = new Map();
        this.activeSessions = new Map();
        this.isMonitoring = false;
    }

    /**
     * Start monitoring Codex sessions
     */
    async startMonitoring() {
        if (this.isMonitoring) {
            return;
        }

        try {
            // Ensure sessions directory exists
            await this.ensureSessionsDirectory();
            
            // Set up file watcher for new session files
            this.setupFileWatcher();
            
            // Scan for existing sessions
            await this.scanExistingSessions();
            
            this.isMonitoring = true;
            this.emit('monitoring_started');
            
            console.log(`Session monitoring started: ${this.sessionsPath}`);
        } catch (error) {
            console.error('Failed to start session monitoring:', error);
            this.emit('monitoring_error', error);
            throw error;
        }
    }

    /**
     * Stop monitoring sessions
     */
    async stopMonitoring() {
        if (!this.isMonitoring) {
            return;
        }

        // Close all file watchers
        for (const watcher of this.watchers.values()) {
            await watcher.close();
        }
        this.watchers.clear();

        this.isMonitoring = false;
        this.emit('monitoring_stopped');
        
        console.log('Session monitoring stopped');
    }

    /**
     * Ensure the sessions directory exists
     */
    async ensureSessionsDirectory() {
        try {
            await fs.access(this.sessionsPath);
        } catch (error) {
            // Directory doesn't exist, create it or use fallback
            console.warn(`Sessions directory not found: ${this.sessionsPath}`);
            this.sessionsPath = path.join(process.cwd(), 'data', 'sessions');
            await fs.mkdir(this.sessionsPath, { recursive: true });
            console.log(`Created fallback sessions directory: ${this.sessionsPath}`);
        }
    }

    /**
     * Set up file watcher for the sessions directory
     */
    setupFileWatcher() {
        const watcher = chokidar.watch(this.sessionsPath, {
            ignored: /(^|[\/\\])\\../, // ignore dotfiles
            persistent: true,
            depth: 3 // Watch subdirectories for date-based structure
        });

        watcher.on('add', (filePath) => {
            if (filePath.endsWith('.jsonl')) {
                this.watchSessionFile(filePath);
            }
        });

        watcher.on('change', (filePath) => {
            if (filePath.endsWith('.jsonl')) {
                this.handleSessionFileChange(filePath);
            }
        });

        watcher.on('unlink', (filePath) => {
            if (filePath.endsWith('.jsonl')) {
                this.unwatchSessionFile(filePath);
            }
        });

        watcher.on('error', (error) => {
            console.error('Session directory watcher error:', error);
            this.emit('watcher_error', error);
        });

        this.watchers.set('main', watcher);
    }

    /**
     * Scan for existing session files
     */
    async scanExistingSessions() {
        try {
            const files = await this.findJSONLFiles(this.sessionsPath);
            
            for (const filePath of files) {
                await this.watchSessionFile(filePath);
            }
            
            console.log(`Found ${files.length} existing session files`);
        } catch (error) {
            console.error('Error scanning existing sessions:', error);
        }
    }

    /**
     * Recursively find JSONL files
     */
    async findJSONLFiles(dir) {
        const files = [];
        
        try {
            const entries = await fs.readdir(dir, { withFileTypes: true });
            
            for (const entry of entries) {
                const fullPath = path.join(dir, entry.name);
                
                if (entry.isDirectory()) {
                    const subFiles = await this.findJSONLFiles(fullPath);
                    files.push(...subFiles);
                } else if (entry.name.endsWith('.jsonl')) {
                    files.push(fullPath);
                }
            }
        } catch (error) {
            // Directory might not be accessible, skip
        }
        
        return files;
    }

    /**
     * Start watching a specific session file
     */
    async watchSessionFile(filePath) {
        if (this.activeSessions.has(filePath)) {
            return; // Already watching
        }

        try {
            const sessionId = this.extractSessionId(filePath);
            const session = {
                id: sessionId,
                filePath,
                lastPosition: 0,
                entries: [],
                startTime: new Date(),
                status: 'active'
            };

            this.activeSessions.set(filePath, session);
            
            // Read existing content
            await this.readSessionFile(filePath);
            
            this.emit('session_discovered', { sessionId, filePath });
            console.log(`Watching session: ${sessionId} at ${filePath}`);
        } catch (error) {
            console.error(`Error watching session file ${filePath}:`, error);
        }
    }

    /**
     * Stop watching a session file
     */
    unwatchSessionFile(filePath) {
        const session = this.activeSessions.get(filePath);
        if (session) {
            session.status = 'ended';
            this.emit('session_ended', { sessionId: session.id, filePath });
            this.activeSessions.delete(filePath);
            console.log(`Stopped watching session: ${session.id}`);
        }
    }

    /**
     * Handle changes to a session file
     */
    async handleSessionFileChange(filePath) {
        try {
            await this.readSessionFile(filePath);
        } catch (error) {
            console.error(`Error reading changed session file ${filePath}:`, error);
        }
    }

    /**
     * Read and parse session file content
     */
    async readSessionFile(filePath) {
        const session = this.activeSessions.get(filePath);
        if (!session) {
            return;
        }

        try {
            const content = await fs.readFile(filePath, 'utf8');
            const lines = content.split('\\n');
            
            // Process new lines since last read
            const newLines = lines.slice(session.lastPosition);
            
            for (const line of newLines) {
                if (line.trim()) {
                    try {
                        const entry = JSON.parse(line);
                        session.entries.push({
                            ...entry,
                            timestamp: new Date(),
                            lineNumber: session.entries.length + 1
                        });
                        
                        this.emit('session_entry', {
                            sessionId: session.id,
                            entry,
                            filePath
                        });
                    } catch (parseError) {
                        // Invalid JSON line, skip or log
                        console.warn(`Invalid JSON in session ${session.id}:`, line);
                    }
                }
            }
            
            session.lastPosition = lines.length;
            session.lastUpdated = new Date();
        } catch (error) {
            console.error(`Error reading session file ${filePath}:`, error);
        }
    }

    /**
     * Extract session ID from file path
     */
    extractSessionId(filePath) {
        // Extract from path like: ~/.codex/sessions/2024/09/27/session_123.jsonl
        const basename = path.basename(filePath, '.jsonl');
        const dirname = path.dirname(filePath);
        const dateParts = dirname.split(path.sep).slice(-3).join('-');
        return `${dateParts}_${basename}`;
    }

    /**
     * Get session by ID
     */
    getSession(sessionId) {
        for (const session of this.activeSessions.values()) {
            if (session.id === sessionId) {
                return session;
            }
        }
        return null;
    }

    /**
     * Get all active sessions
     */
    getAllSessions() {
        return Array.from(this.activeSessions.values());
    }

    /**
     * Map session entries to task events
     */
    mapEntryToTaskEvent(entry, sessionId) {
        // This would map Codex JSONL entries to our task event format
        // The exact mapping depends on Codex CLI output format
        const eventMap = {
            'task_started': 'taskStarted',
            'task_completed': 'taskCompleted',
            'task_failed': 'taskFailed',
            'approval_required': 'taskProgress',
            'progress_update': 'taskProgress'
        };

        return {
            type: eventMap[entry.type] || 'taskProgress',
            sessionId,
            timestamp: entry.timestamp || new Date().toISOString(),
            data: entry
        };
    }

    /**
     * Get monitoring statistics
     */
    getStats() {
        const sessions = Array.from(this.activeSessions.values());
        return {
            isMonitoring: this.isMonitoring,
            activeSessions: sessions.length,
            totalEntries: sessions.reduce((sum, s) => sum + s.entries.length, 0),
            sessionsPath: this.sessionsPath,
            watchers: this.watchers.size
        };
    }
}

module.exports = SessionMonitor;