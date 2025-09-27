const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs').promises;

/**
 * Database service for task persistence using SQLite
 */
class DatabaseService {
    constructor(options = {}) {
        this.dbPath = options.dbPath || path.join(process.cwd(), 'data', 'conductor.db');
        this.db = null;
    }

    /**
     * Initialize database connection and create tables
     */
    async initialize() {
        try {
            // Ensure data directory exists
            const dataDir = path.dirname(this.dbPath);
            await fs.mkdir(dataDir, { recursive: true });

            return new Promise((resolve, reject) => {
                this.db = new sqlite3.Database(this.dbPath, (err) => {
                    if (err) {
                        reject(err);
                    } else {
                        console.log(`Database connected: ${this.dbPath}`);
                        this.createTables().then(resolve).catch(reject);
                    }
                });
            });
        } catch (error) {
            console.error('Database initialization failed:', error);
            throw error;
        }
    }

    /**
     * Create database tables
     */
    async createTables() {
        const createTasksTable = `
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                prompt TEXT NOT NULL,
                working_dir TEXT,
                approval_mode TEXT DEFAULT 'suggest',
                status TEXT DEFAULT 'pending',
                start_time DATETIME,
                end_time DATETIME,
                exit_code INTEGER,
                result TEXT,
                error TEXT,
                process_id INTEGER,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `;

        const createTaskLogsTable = `
            CREATE TABLE IF NOT EXISTS task_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT NOT NULL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                type TEXT NOT NULL,
                message TEXT,
                data TEXT,
                FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
            )
        `;

        const createSessionsTable = `
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                file_path TEXT NOT NULL,
                status TEXT DEFAULT 'active',
                start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
                end_time DATETIME,
                entry_count INTEGER DEFAULT 0,
                last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `;

        const createIndexes = [
            'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)',
            'CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at)',
            'CREATE INDEX IF NOT EXISTS idx_task_logs_task_id ON task_logs(task_id)',
            'CREATE INDEX IF NOT EXISTS idx_task_logs_timestamp ON task_logs(timestamp)',
            'CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status)'
        ];

        return new Promise((resolve, reject) => {
            this.db.serialize(() => {
                this.db.run(createTasksTable);
                this.db.run(createTaskLogsTable);
                this.db.run(createSessionsTable);
                
                // Create indexes
                createIndexes.forEach(indexSQL => {
                    this.db.run(indexSQL);
                });

                resolve();
            });
        });
    }

    /**
     * Save task to database
     */
    async saveTask(task) {
        const sql = `
            INSERT OR REPLACE INTO tasks 
            (id, prompt, working_dir, approval_mode, status, start_time, end_time, 
             exit_code, result, error, process_id, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        `;

        const params = [
            task.id,
            task.prompt,
            task.workingDir,
            task.approvalMode,
            task.status,
            task.startTime?.toISOString(),
            task.endTime?.toISOString(),
            task.exitCode,
            task.result,
            task.error,
            task.processId
        ];

        return new Promise((resolve, reject) => {
            this.db.run(sql, params, function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve({ id: task.id, changes: this.changes });
                }
            });
        });
    }

    /**
     * Load task from database
     */
    async loadTask(taskId) {
        const sql = 'SELECT * FROM tasks WHERE id = ?';
        
        return new Promise((resolve, reject) => {
            this.db.get(sql, [taskId], (err, row) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(row ? this.deserializeTask(row) : null);
                }
            });
        });
    }

    /**
     * Load all tasks with optional filtering
     */
    async loadTasks(options = {}) {
        let sql = 'SELECT * FROM tasks';
        const params = [];
        const conditions = [];

        if (options.status) {
            conditions.push('status = ?');
            params.push(options.status);
        }

        if (options.since) {
            conditions.push('created_at >= ?');
            params.push(options.since.toISOString());
        }

        if (conditions.length > 0) {
            sql += ' WHERE ' + conditions.join(' AND ');
        }

        sql += ' ORDER BY created_at DESC';

        if (options.limit) {
            sql += ' LIMIT ?';
            params.push(options.limit);
        }

        return new Promise((resolve, reject) => {
            this.db.all(sql, params, (err, rows) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(rows.map(row => this.deserializeTask(row)));
                }
            });
        });
    }

    /**
     * Save task log entry
     */
    async saveTaskLog(taskId, logEntry) {
        const sql = `
            INSERT INTO task_logs (task_id, timestamp, type, message, data)
            VALUES (?, ?, ?, ?, ?)
        `;

        const params = [
            taskId,
            logEntry.timestamp?.toISOString() || new Date().toISOString(),
            logEntry.type,
            logEntry.message,
            logEntry.data ? JSON.stringify(logEntry.data) : null
        ];

        return new Promise((resolve, reject) => {
            this.db.run(sql, params, function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve({ id: this.lastID });
                }
            });
        });
    }

    /**
     * Load task logs
     */
    async loadTaskLogs(taskId, options = {}) {
        let sql = 'SELECT * FROM task_logs WHERE task_id = ?';
        const params = [taskId];

        if (options.since) {
            sql += ' AND timestamp >= ?';
            params.push(options.since.toISOString());
        }

        sql += ' ORDER BY timestamp ASC';

        if (options.limit) {
            sql += ' LIMIT ?';
            params.push(options.limit);
        }

        return new Promise((resolve, reject) => {
            this.db.all(sql, params, (err, rows) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(rows.map(row => ({
                        id: row.id,
                        taskId: row.task_id,
                        timestamp: new Date(row.timestamp),
                        type: row.type,
                        message: row.message,
                        data: row.data ? JSON.parse(row.data) : null
                    })));
                }
            });
        });
    }

    /**
     * Save session information
     */
    async saveSession(session) {
        const sql = `
            INSERT OR REPLACE INTO sessions 
            (id, file_path, status, start_time, end_time, entry_count, last_updated)
            VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        `;

        const params = [
            session.id,
            session.filePath,
            session.status,
            session.startTime?.toISOString(),
            session.endTime?.toISOString(),
            session.entries?.length || 0
        ];

        return new Promise((resolve, reject) => {
            this.db.run(sql, params, function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve({ id: session.id, changes: this.changes });
                }
            });
        });
    }

    /**
     * Delete old tasks and logs
     */
    async cleanup(maxAge = 7 * 24 * 60 * 60 * 1000) { // 7 days default
        const cutoffDate = new Date(Date.now() - maxAge).toISOString();
        
        const deleteOldTasks = 'DELETE FROM tasks WHERE end_time < ? AND status IN ("completed", "failed", "cancelled")';
        const deleteOldLogs = 'DELETE FROM task_logs WHERE timestamp < ?';
        const deleteOldSessions = 'DELETE FROM sessions WHERE end_time < ?';

        return new Promise((resolve, reject) => {
            this.db.serialize(() => {
                let deletedTasks = 0;
                let deletedLogs = 0;
                let deletedSessions = 0;

                this.db.run(deleteOldTasks, [cutoffDate], function(err) {
                    if (!err) deletedTasks = this.changes;
                });

                this.db.run(deleteOldLogs, [cutoffDate], function(err) {
                    if (!err) deletedLogs = this.changes;
                });

                this.db.run(deleteOldSessions, [cutoffDate], function(err) {
                    if (err) {
                        reject(err);
                    } else {
                        deletedSessions = this.changes;
                        resolve({ deletedTasks, deletedLogs, deletedSessions });
                    }
                });
            });
        });
    }

    /**
     * Get database statistics
     */
    async getStats() {
        const queries = [
            'SELECT COUNT(*) as total_tasks FROM tasks',
            'SELECT COUNT(*) as active_tasks FROM tasks WHERE status IN ("running", "waiting_approval", "starting")',
            'SELECT COUNT(*) as completed_tasks FROM tasks WHERE status = "completed"',
            'SELECT COUNT(*) as failed_tasks FROM tasks WHERE status = "failed"',
            'SELECT COUNT(*) as total_logs FROM task_logs',
            'SELECT COUNT(*) as active_sessions FROM sessions WHERE status = "active"'
        ];

        const stats = {};

        for (const query of queries) {
            const result = await new Promise((resolve, reject) => {
                this.db.get(query, (err, row) => {
                    if (err) reject(err);
                    else resolve(row);
                });
            });

            Object.assign(stats, result);
        }

        return stats;
    }

    /**
     * Convert database row to task object
     */
    deserializeTask(row) {
        return {
            id: row.id,
            prompt: row.prompt,
            workingDir: row.working_dir,
            approvalMode: row.approval_mode,
            status: row.status,
            startTime: row.start_time ? new Date(row.start_time) : null,
            endTime: row.end_time ? new Date(row.end_time) : null,
            exitCode: row.exit_code,
            result: row.result,
            error: row.error,
            processId: row.process_id,
            createdAt: new Date(row.created_at),
            updatedAt: new Date(row.updated_at)
        };
    }

    /**
     * Close database connection
     */
    async close() {
        if (this.db) {
            return new Promise((resolve) => {
                this.db.close((err) => {
                    if (err) {
                        console.error('Error closing database:', err);
                    } else {
                        console.log('Database connection closed');
                    }
                    resolve();
                });
            });
        }
    }
}

module.exports = DatabaseService;