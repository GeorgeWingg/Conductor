# Backend Development Vision & Team Guide

## 🎯 Project Vision

We're building the **backend brain** for an AI-powered Mac toolbar assistant that makes complex tasks feel effortless. Our backend serves as the bridge between beautiful Swift UI and powerful AI capabilities through OpenAI Codex CLI.

### What We're Creating
A **Node.js API server** that:
- **Wraps OpenAI Codex CLI** to make AI accessible via clean REST endpoints
- **Provides real-time feedback** through Socket.IO for that smooth "thinking" experience
- **Handles file system operations** safely across different operating systems
- **Manages task execution** with progress tracking and error recovery

### The User Experience We're Enabling
1. **User clicks toolbar** → Sleek dropdown appears
2. **User speaks command** → "organize the files on my system"
3. **Backend processes** → Shows real-time thinking steps
4. **Task completes** → Suggests logical next actions
5. **Seamless flow** → No technical complexity exposed to user

---

## 🚧 Cross-Platform Development Challenges

### **Windows (You) ↔ Mac (Team) Coordination**

#### **Path Handling Gotchas**
```javascript
// ❌ DON'T - Windows-specific paths
const filePath = "C:\\Users\\Desktop\\file.txt";

// ✅ DO - Cross-platform paths
const path = require('path');
const filePath = path.join(os.homedir(), 'Desktop', 'file.txt');
```

#### **Line Ending Issues**
```bash
# Configure git to handle line endings automatically
git config --global core.autocrlf true  # Windows
git config --global core.autocrlf input # Mac (for your teammates)
```

#### **File Permissions**
```javascript
// Mac files might have different permissions
// Always check file access before operations
await fs.access(filePath, fs.constants.R_OK | fs.constants.W_OK);
```

---

## 🔄 Git Workflow Strategy

### **Branch Protection Strategy**
```bash
# Main development workflow
main branch         ← Production-ready code (protected)
  ↳ develop branch  ← Integration branch
    ↳ feature/backend-* ← Your backend features
    ↳ feature/frontend-* ← Mac team's UI features
```

### **Your Daily Git Workflow**
```bash
# Start your day
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/backend-codex-integration

# Work on your changes...
git add .
git commit -m "feat: add codex CLI wrapper with progress tracking"

# Push and create PR
git push origin feature/backend-codex-integration
# Then create Pull Request to develop branch
```

### **Critical Git Settings for Team**
```bash
# Prevent merge conflicts with package-lock.json
echo "package-lock.json merge=ours" >> .gitattributes

# Add this to .gitignore
node_modules/
.env
.DS_Store          # Mac-specific
Thumbs.db          # Windows-specific
*.log
dist/
build/
```

---

## ⚠️ Platform-Specific Gotchas

### **OpenAI Codex CLI Issues**

#### **Windows Specific:**
```javascript
// Command execution might need different handling
const isWindows = process.platform === 'win32';
const codexCommand = isWindows ? 'codex.exe' : 'codex';

// Path handling for CLI output
const outputPath = isWindows 
  ? path.resolve(process.cwd(), 'output') 
  : path.join(process.cwd(), 'output');
```

#### **Mac Team Testing:**
- They'll need to install Codex CLI on their machines
- Environment variables might be in different locations
- Permission issues with file system access

### **Network & Socket.IO Considerations**
```javascript
// Mac machines might have different localhost resolution
const SERVER_URL = process.env.NODE_ENV === 'development' 
  ? 'http://localhost:3001'  // Your Windows machine
  : 'https://your-production-server.com';

// Allow connections from Mac team's machines
const corsOptions = {
  origin: [
    'http://localhost:3000',      // Standard frontend
    'http://192.168.*.*:3000',    // Local network access
    'http://10.*.*.*:3000'        // Alternative local networks
  ]
};
```

---

## 🛡️ Security & Safety Considerations

### **File System Security**
```javascript
// ALWAYS validate paths to prevent directory traversal
function sanitizePath(userPath) {
  const normalized = path.normalize(userPath);
  
  // Prevent ../.. attacks
  if (normalized.includes('..')) {
    throw new Error('Invalid path');
  }
  
  // Restrict to user's home directory and safe locations
  const homeDir = os.homedir();
  const safePaths = [
    path.join(homeDir, 'Desktop'),
    path.join(homeDir, 'Documents'),
    path.join(homeDir, 'Downloads')
  ];
  
  const isInSafePath = safePaths.some(safePath => 
    normalized.startsWith(safePath)
  );
  
  if (!isInSafePath) {
    throw new Error('Access denied to this directory');
  }
  
  return normalized;
}
```

### **API Key Management**
```bash
# NEVER commit API keys to git
# Use .env files that are gitignored
echo "OPENAI_API_KEY=your-key-here" >> .env
echo ".env" >> .gitignore

# For the team, create .env.example
echo "OPENAI_API_KEY=your-openai-key-here" >> .env.example
echo "API_KEY=your-backend-api-key" >> .env.example
```

---

## 🔧 Development Environment Setup

### **Your Windows Setup Checklist**
- [ ] Node.js 18+ installed
- [ ] OpenAI Codex CLI installed and configured
- [ ] Git configured with proper line endings
- [ ] Environment variables set up
- [ ] Network firewall allows port 3001

### **Mac Team Requirements**
- [ ] Node.js 18+ for testing backend locally
- [ ] OpenAI Codex CLI installed
- [ ] Xcode 14+ for Swift development
- [ ] Network access to your development machine

### **Shared Development Commands**
```bash
# Everyone should be able to run these
npm install          # Install dependencies
npm run dev         # Start development server
npm test            # Run tests
npm run lint        # Check code quality

# Backend-specific (you)
node test-codex.js  # Test Codex CLI integration
curl http://localhost:3001/health  # Test API health
```

---

## 🚀 Deployment & Production Planning

### **Development → Production Path**
1. **Local Development** (Your Windows machine)
2. **Team Integration** (Shared development server)
3. **Staging Environment** (Production-like testing)
4. **Production Deployment** (Cloud hosting)

### **Backend Hosting Options**
```javascript
// Configuration for different environments
const config = {
  development: {
    port: 3001,
    host: 'localhost',
    codexPath: 'codex'  // Assume in PATH
  },
  production: {
    port: process.env.PORT || 8080,
    host: '0.0.0.0',
    codexPath: '/usr/local/bin/codex'  // Full path in production
  }
};
```

---

## 📊 Monitoring & Debugging

### **Key Metrics to Track**
```javascript
// Add these to your backend for production readiness
const metrics = {
  tasksCompleted: 0,
  tasksInProgress: 0,
  averageTaskTime: 0,
  errorRate: 0,
  codexApiCalls: 0
};

// Log important events
console.log(`[${new Date().toISOString()}] Task started: ${taskId}`);
console.log(`[${new Date().toISOString()}] Codex response time: ${duration}ms`);
```

### **Common Debug Scenarios**
```javascript
// Debug helpers for cross-platform issues
function debugEnvironment() {
  console.log('Platform:', process.platform);
  console.log('Node version:', process.version);
  console.log('Working directory:', process.cwd());
  console.log('Home directory:', os.homedir());
  console.log('Environment:', process.env.NODE_ENV);
}

// Call this during development
if (process.env.NODE_ENV === 'development') {
  debugEnvironment();
}
```

---

## 🤝 Team Communication Protocol

### **Daily Sync (Async via Slack/Discord)**
**Your Daily Update Format:**
```
🔧 Backend Progress:
✅ Completed: Codex CLI integration working
🚧 In Progress: Real-time progress indicators
❌ Blocked: Need clarification on file organization scope
📋 Next: Socket.IO event structure for UI team
```

### **When to Sync with Mac Team**
- **API contract changes** → Immediate notification
- **New endpoints ready** → Share Postman collection/cURL examples
- **Breaking changes** → Schedule pair programming session
- **Integration testing** → Coordinate local testing

### **Code Review Focus Areas**
- **Security**: File path validation, input sanitization
- **Error Handling**: Graceful failures, proper error messages
- **Performance**: Task cleanup, memory management
- **Cross-Platform**: Path handling, command execution

---

## 🎯 Success Metrics

### **Technical Goals**
- [ ] **Response Time**: < 2 seconds for API calls
- [ ] **Reliability**: 99%+ uptime during development
- [ ] **Security**: Zero directory traversal vulnerabilities
- [ ] **Compatibility**: Works on both Windows dev and Mac testing

### **Team Goals**
- [ ] **Zero Integration Blockers**: Mac team never blocked on backend
- [ ] **Clear API Contract**: All endpoints documented and stable
- [ ] **Smooth Handoffs**: Features work end-to-end first try
- [ ] **Version Compatibility**: No breaking changes without notice

---

## 🚨 Emergency Protocols

### **If Codex CLI Breaks**
```javascript
// Fallback mode for development
const MOCK_MODE = process.env.MOCK_CODEX === 'true';

if (MOCK_MODE) {
  // Return mock responses for UI development
  return {
    taskId: 'mock-' + Date.now(),
    status: 'completed',
    result: 'Mock file organization complete'
  };
}
```

### **If Mac Team Can't Connect**
1. **Check Windows Firewall**: Allow port 3001
2. **Get Local IP**: `ipconfig` → share IP with team
3. **Test Connection**: `curl http://YOUR_IP:3001/health`
4. **Fallback**: Use ngrok for temporary public URL

### **Git Merge Conflicts**
```bash
# Safe conflict resolution
git status                    # See what's conflicted
git checkout --theirs file    # Take their version
git checkout --ours file      # Take your version
git add file                  # Mark as resolved
```

Remember: **You're building the foundation that makes magic happen in the UI.** Every endpoint you create, every real-time update you send, every error you handle gracefully contributes to that seamless "just works" experience users will love. 

The Mac team is counting on you to make AI feel effortless! 🚀