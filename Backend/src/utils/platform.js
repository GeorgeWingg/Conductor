const os = require('os');
const path = require('path');

/**
 * Cross-platform utilities for handling OS differences
 */
class PlatformUtils {
    static isWindows() {
        return process.platform === 'win32';
    }

    static isMac() {
        return process.platform === 'darwin';
    }

    static isLinux() {
        return process.platform === 'linux';
    }

    static getCodexCommand() {
        return this.isWindows() ? 'codex.exe' : 'codex';
    }

    static getHomePath() {
        return os.homedir();
    }

    static getCodexConfigPath() {
        const homeDir = this.getHomePath();
        return path.join(homeDir, '.codex');
    }

    static getCodexSessionsPath() {
        const configPath = this.getCodexConfigPath();
        return path.join(configPath, 'sessions');
    }

    static sanitizePath(userPath) {
        const normalized = path.normalize(userPath);
        
        // Prevent directory traversal attacks
        if (normalized.includes('..')) {
            throw new Error('Invalid path: directory traversal not allowed');
        }
        
        // Restrict to safe directories
        const homeDir = path.resolve(this.getHomePath());
        const normalizedInput = path.resolve(normalized);
        
        const safePaths = [
            path.join(homeDir, 'Desktop'),
            path.join(homeDir, 'Documents'),
            path.join(homeDir, 'Downloads'),
            path.join(homeDir, 'Projects'),
            path.join(homeDir, 'OneDrive', 'Desktop'),
            path.join(homeDir, 'OneDrive', 'Documents'),
            path.join(homeDir, 'OneDrive', 'Downloads'),
            path.resolve(process.cwd()) // Allow current working directory
        ];
        
        const isInSafePath = safePaths.some(safePath => {
            const resolvedSafePath = path.resolve(safePath);
            return normalizedInput.startsWith(resolvedSafePath);
        });
        
        if (!isInSafePath) {
            throw new Error('Access denied: path outside safe directories');
        }
        
        return normalized;
    }

    static debugEnvironment() {
        return {
            platform: process.platform,
            nodeVersion: process.version,
            workingDirectory: process.cwd(),
            homeDirectory: this.getHomePath(),
            environment: process.env.NODE_ENV || 'development',
            codexCommand: this.getCodexCommand(),
            codexConfigPath: this.getCodexConfigPath()
        };
    }
}

module.exports = PlatformUtils;