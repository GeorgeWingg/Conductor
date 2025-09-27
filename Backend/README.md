# Conductor Backend

AI-powered task management backend that wraps OpenAI Codex CLI for seamless automation through a macOS toolbar interface.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Set up environment
npm run setup

# Start development server
npm run dev

# Run tests
npm test
```

## 🏗️ Architecture

The Conductor Backend serves as the bridge between your macOS Swift UI and powerful AI capabilities:

- **Express.js API Server** - RESTful endpoints for task management
- **Socket.IO WebSockets** - Real-time progress updates and notifications  
- **Codex CLI Wrapper** - Cross-platform integration with OpenAI Codex
- **SQLite Database** - Task persistence and history
- **Session Monitor** - JSONL log parsing and session tracking

## 📡 API Endpoints

### Health & System
- `GET /health` - Server health check
- `GET /api/system/status` - Detailed system status
- `GET /api/system/config` - Configuration information

### Task Management
- `POST /api/tasks` - Create new task
- `GET /api/tasks` - Get all tasks
- `GET /api/tasks/:id` - Get specific task
- `POST /api/tasks/:id/approve` - Approve pending task
- `DELETE /api/tasks/:id` - Cancel task
- `GET /api/tasks/:id/logs` - Get task logs

### WebSocket Events
- `task_created` - New task started
- `task_progress` - Task progress update
- `task_completed` - Task finished successfully
- `task_failed` - Task failed
- `task_log` - New log entry

## 🔧 Configuration

Create `.env` file (copy from `.env.example`):

```bash
# Server Configuration
NODE_ENV=development
PORT=3001
HOST=localhost

# OpenAI Configuration  
OPENAI_API_KEY=your-openai-key-here

# Codex CLI Configuration
CODEX_CLI_PATH=codex
MOCK_CODEX=false

# Security
API_SECRET=your-api-secret-here

# Database
DB_PATH=./data/conductor.db

# CORS Origins
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
```

## 🖥️ Cross-Platform Support

### Windows Development (You)
```bash
# Ensure proper Git line endings
git config core.autocrlf true

# Start development server
npm run dev
```

### Mac Team Testing
```bash
# Git configuration for Mac
git config core.autocrlf input

# Start backend for Mac team testing
npm start
```

## 🧪 Testing

```bash
# Run all tests
npm test

# Test specific functionality
node test/test-runner.js

# Manual API testing
curl http://localhost:3001/health
```

## 🔒 Security Features

- **Rate Limiting** - 100 requests per 15 minutes
- **Input Validation** - Sanitization and validation
- **Path Safety** - Directory traversal protection  
- **CORS Protection** - Configurable origins
- **Security Headers** - Helmet.js integration
- **API Key Authentication** - Optional API key protection

## 📊 Mock Mode

For development without Codex CLI:

```bash
MOCK_CODEX=true npm run dev
```

Mock mode simulates:
- Task execution with fake progress
- Realistic timing and events
- Error scenarios for testing
- Log generation

## 🔧 Development Workflow

### Daily Development
```bash
# Start your work
git checkout develop
git pull origin develop

# Create feature branch  
git checkout -b feature/backend-new-feature

# Make changes and test
npm run dev
npm test

# Commit and push
git add .
git commit -m "feat: add new feature"
git push origin feature/backend-new-feature
```

### Team Integration
```bash
# Make backend accessible to Mac team
# Option 1: Local network (update CORS_ORIGINS in .env)
CORS_ORIGINS="http://192.168.1.100:3000" npm start

# Option 2: Use ngrok for external access  
npx ngrok http 3001
```

## 📁 Project Structure

```
Backend/
├── src/
│   ├── services/          # Core business logic
│   │   ├── codex.js      # Codex CLI wrapper
│   │   ├── websocket.js  # Real-time communication
│   │   ├── database.js   # Data persistence
│   │   └── session-monitor.js # JSONL log monitoring
│   ├── routes/           # API route handlers
│   │   ├── tasks.js      # Task management endpoints
│   │   └── system.js     # System information endpoints
│   ├── middleware/       # Express middleware
│   │   └── security.js   # Security and validation
│   ├── utils/           # Utility functions
│   │   └── platform.js   # Cross-platform helpers
│   └── server.js        # Main server application
├── test/                # Test suite
├── scripts/             # Setup and utility scripts
├── data/               # SQLite database and logs
└── package.json        # Dependencies and scripts
```

## 🐛 Troubleshooting

### Common Issues

**Server won't start:**
```bash
# Check Node.js version (18+ required)
node --version

# Verify dependencies
npm install

# Check environment
npm run setup
```

**Codex CLI not found:**
```bash
# Install Codex CLI
npm install -g @openai/codex-cli

# Or use mock mode
MOCK_CODEX=true npm run dev
```

**Database errors:**
```bash
# Recreate database
rm -rf data/conductor.db
npm run setup
```

**Mac team can't connect:**
```bash
# Check Windows firewall (allow port 3001)
# Update CORS_ORIGINS in .env
# Verify local IP with: ipconfig
```

### Debug Mode

```bash
NODE_ENV=development npm run dev
```

Provides:
- Detailed error messages
- Request/response logging
- Platform information
- Connection debugging

## 🚀 Production Deployment

### Environment Setup
```bash
NODE_ENV=production
PORT=8080
HOST=0.0.0.0
API_SECRET=secure-random-key
```

### Process Management
```bash
# Using PM2
npm install -g pm2
pm2 start src/server.js --name conductor-backend

# Using Docker
docker build -t conductor-backend .
docker run -p 8080:8080 conductor-backend
```

## 📈 Monitoring

### Health Checks
- `GET /health` - Basic health status
- `GET /api/system/status` - Detailed metrics
- `GET /api/websocket/stats` - WebSocket statistics
- `GET /api/database/stats` - Database statistics

### Logs
```bash
# Development logs
tail -f logs/conductor.log

# Production logs with PM2
pm2 logs conductor-backend
```

## 🤝 Team Communication

### Daily Updates Template
```
🔧 Backend Progress:
✅ Completed: [Feature/fix completed]
🚧 In Progress: [Current work]
❌ Blocked: [Issues needing help]  
📋 Next: [Planned next steps]
```

### Integration Points
- **API Contract Changes** → Immediate Slack notification
- **New Endpoints** → Share cURL examples
- **Breaking Changes** → Coordinate deployment
- **Testing Ready** → Demo endpoints and WebSocket events

## 📚 API Examples

### Create Task
```bash
curl -X POST http://localhost:3001/api/tasks \\
  -H "Content-Type: application/json" \\
  -d '{
    "prompt": "organize the files on my desktop",
    "workingDir": "/Users/username/Desktop",
    "approvalMode": "suggest"
  }'
```

### WebSocket Connection (JavaScript)
```javascript
const socket = io('http://localhost:3001');

socket.on('connect', () => {
  console.log('Connected to Conductor Backend');
  
  // Subscribe to all task updates
  socket.emit('subscribe_all_tasks');
});

socket.on('task_event', (event) => {
  console.log('Task update:', event);
});
```

---

**Built for the Hackathon Weekend** 🏁  
*Making AI feel effortless through seamless backend magic* ✨