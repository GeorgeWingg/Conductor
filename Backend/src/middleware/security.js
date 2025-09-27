const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

/**
 * Security middleware configuration
 */

// Rate limiting configuration
const createRateLimiter = (windowMs = 15 * 60 * 1000, max = 100) => {
    return rateLimit({
        windowMs,
        max,
        message: {
            success: false,
            error: 'Too many requests, please try again later',
            retryAfter: Math.ceil(windowMs / 1000)
        },
        standardHeaders: true,
        legacyHeaders: false,
        skip: (req) => {
            // Skip rate limiting for health checks in development
            return process.env.NODE_ENV === 'development' && req.path === '/health';
        }
    });
};

// API key validation middleware
const validateApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'] || req.query.apiKey;
    const expectedApiKey = process.env.API_SECRET;

    // Skip API key validation in development mode
    if (process.env.NODE_ENV === 'development' && !expectedApiKey) {
        return next();
    }

    if (!apiKey || apiKey !== expectedApiKey) {
        return res.status(401).json({
            success: false,
            error: 'Invalid or missing API key'
        });
    }

    next();
};

// Request validation middleware
const validateTaskRequest = (req, res, next) => {
    const { prompt, workingDir, approvalMode } = req.body;

    // Validate required fields
    if (!prompt || typeof prompt !== 'string' || prompt.trim().length === 0) {
        return res.status(400).json({
            success: false,
            error: 'Prompt is required and must be a non-empty string'
        });
    }

    // Validate prompt length
    if (prompt.length > 10000) {
        return res.status(400).json({
            success: false,
            error: 'Prompt too long (maximum 10,000 characters)'
        });
    }

    // Validate approval mode
    const validApprovalModes = ['suggest', 'auto-edit', 'full-auto'];
    if (approvalMode && !validApprovalModes.includes(approvalMode)) {
        return res.status(400).json({
            success: false,
            error: `Invalid approval mode. Must be one of: ${validApprovalModes.join(', ')}`
        });
    }

    // Validate working directory if provided
    if (workingDir && typeof workingDir !== 'string') {
        return res.status(400).json({
            success: false,
            error: 'Working directory must be a string'
        });
    }

    // Sanitize input
    req.body.prompt = prompt.trim();
    if (workingDir) {
        req.body.workingDir = workingDir.trim();
    }

    next();
};

// Input sanitization middleware
const sanitizeInput = (req, res, next) => {
    // Recursively sanitize object properties
    const sanitize = (obj) => {
        if (typeof obj === 'string') {
            // Remove potentially dangerous characters
            return obj.replace(/[<>\"'&]/g, '');
        } else if (Array.isArray(obj)) {
            return obj.map(sanitize);
        } else if (obj && typeof obj === 'object') {
            const sanitized = {};
            for (const [key, value] of Object.entries(obj)) {
                sanitized[key] = sanitize(value);
            }
            return sanitized;
        }
        return obj;
    };

    // Only sanitize for non-GET requests
    if (req.method !== 'GET') {
        req.body = sanitize(req.body);
    }

    next();
};

// Error handling middleware
const errorHandler = (err, req, res, next) => {
    console.error('Error:', {
        message: err.message,
        stack: err.stack,
        url: req.url,
        method: req.method,
        body: req.body,
        timestamp: new Date().toISOString()
    });

    // Don't send stack trace in production
    const isDevelopment = process.env.NODE_ENV === 'development';

    let statusCode = 500;
    let message = 'Internal server error';

    // Handle specific error types
    if (err.name === 'ValidationError') {
        statusCode = 400;
        message = err.message;
    } else if (err.name === 'UnauthorizedError') {
        statusCode = 401;
        message = 'Unauthorized';
    } else if (err.name === 'ForbiddenError') {
        statusCode = 403;
        message = 'Forbidden';
    } else if (err.name === 'NotFoundError') {
        statusCode = 404;
        message = 'Not found';
    } else if (err.code === 'ENOENT') {
        statusCode = 404;
        message = 'File or directory not found';
    } else if (err.code === 'EACCES') {
        statusCode = 403;
        message = 'Permission denied';
    }

    res.status(statusCode).json({
        success: false,
        error: message,
        ...(isDevelopment && { stack: err.stack, details: err.message })
    });
};

// 404 handler
const notFoundHandler = (req, res) => {
    res.status(404).json({
        success: false,
        error: 'Endpoint not found',
        path: req.path,
        method: req.method
    });
};

// Security headers configuration
const securityHeaders = helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'", "ws:", "wss:"],
            fontSrc: ["'self'"],
            objectSrc: ["'none'"],
            mediaSrc: ["'self'"],
            frameSrc: ["'none'"],
        },
    },
    crossOriginEmbedderPolicy: false, // Disable for WebSocket compatibility
});

// CORS configuration
const getCorsOptions = () => {
    const allowedOrigins = process.env.CORS_ORIGINS 
        ? process.env.CORS_ORIGINS.split(',').map(origin => origin.trim())
        : [
            'http://localhost:3000',
            'http://localhost:8080',
            'http://127.0.0.1:3000',
            'http://127.0.0.1:8080'
        ];

    return {
        origin: (origin, callback) => {
            // Allow requests with no origin (like mobile apps or curl requests)
            if (!origin) return callback(null, true);
            
            if (allowedOrigins.includes(origin) || 
                process.env.NODE_ENV === 'development') {
                return callback(null, true);
            }
            
            return callback(new Error('Not allowed by CORS'));
        },
        credentials: true,
        methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization', 'x-api-key']
    };
};

module.exports = {
    createRateLimiter,
    validateApiKey,
    validateTaskRequest,
    sanitizeInput,
    errorHandler,
    notFoundHandler,
    securityHeaders,
    getCorsOptions
};