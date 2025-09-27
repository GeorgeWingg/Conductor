# Backend Steps - Conductor API Integration Guide

This document provides step-by-step instructions for integrating with the Conductor Backend API to manage AI-powered tasks through OpenAI Codex CLI.

## 🚀 Quick Start

### Server Information
- **Base URL**: `http://localhost:3001`
- **Health Check**: `GET /health`
- **WebSocket**: `ws://localhost:3001`
- **Authentication**: None required in development mode

### Prerequisites
- Conductor Backend server running on port 3001
- OpenAI ChatGPT Plus subscription (for real Codex CLI execution)
- CORS configured for your domain (default: localhost:3000, localhost:8080)

---

## 📡 API Endpoints

### 1. Health Check
Check if the backend is running and healthy.

```http
GET /health
```

**Response:**
```json
{
  "success": true,
  "status": "healthy",
  "timestamp": "2025-09-27T12:16:53.313Z",
  "services": {
    "codex": true,
    "database": true,
    "websocket": true,
    "sessionMonitor": true
  }
}
```

### 2. Create New Task
Submit a new task to be executed by Codex CLI.

```http
POST /api/tasks
Content-Type: application/json

{
  "prompt": "organize the files on my desktop by creating logical folder structures",
  "workingDir": "C:/Users/username/Desktop",
  "approvalMode": "suggest"
}
```

**Parameters:**
- `prompt` (required): Description of the task to perform
- `workingDir` (optional): Working directory path (defaults to backend directory)
- `approvalMode` (optional): One of:
  - `"suggest"` - Interactive mode with approval prompts (default)
  - `"full-auto"` - Automatic execution with workspace sandbox
  - `"danger"` - Full system access (use carefully)

**Response:**
```json
{
  "success": true,
  "data": {
    "taskId": "task_1758975413313_1",
    "status": "running",
    "prompt": "organize the files on my desktop by creating logical folder structures"
  }
}
```

### 3. Get All Tasks
Retrieve list of all tasks.

```http
GET /api/tasks
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "task_1758975413313_1",
      "prompt": "organize the files on my desktop",
      "workingDir": "C:\\Users\\savbo\\OneDrive\\Desktop",
      "approvalMode": "suggest",
      "status": "completed",
      "startTime": "2025-09-27T12:16:53.313Z",
      "endTime": "2025-09-27T12:16:58.812Z",
      "exitCode": 0,
      "logs": [...]
    }
  ],
  "count": 1
}
```

### 4. Get Specific Task
Retrieve details for a specific task by ID.

```http
GET /api/tasks/{taskId}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "task_1758975413313_1",
    "prompt": "what files are in this directory?",
    "workingDir": "C:\\Users\\savbo\\OneDrive\\Desktop\\Conductor\\Backend",
    "approvalMode": "suggest",
    "status": "completed",
    "startTime": "2025-09-27T12:16:53.313Z",
    "endTime": "2025-09-27T12:16:58.812Z",
    "exitCode": 0,
    "logs": [
      {
        "timestamp": "2025-09-27T12:16:53.774Z",
        "type": "stderr",
        "message": "The existing `--json` output format is being deprecated..."
      },
      {
        "timestamp": "2025-09-27T12:16:57.318Z",
        "type": "stdout", 
        "message": "Directory listing output..."
      }
    ],
    "processId": 38604
  }
}
```

### 5. Approve Pending Task
Approve or reject a task waiting for approval.

```http
POST /api/tasks/{taskId}/approve
Content-Type: application/json

{
  "approved": true
}
```

**Parameters:**
- `approved` (boolean): `true` to approve, `false` to reject

### 6. Cancel Task
Cancel a running or pending task.

```http
DELETE /api/tasks/{taskId}
```

### 7. Get Task Logs
Retrieve logs for a specific task.

```http
GET /api/tasks/{taskId}/logs
```

### 8. System Status
Get detailed system information and statistics.

```http
GET /api/system/status
```

**Response:**
```json
{
  "success": true,
  "data": {
    "codex": {
      "available": true,
      "version": "codex-cli 0.42.0",
      "path": "codex"
    },
    "tasks": {
      "total": 5,
      "completed": 3,
      "failed": 1,
      "running": 1,
      "waiting_approval": 0,
      "cancelled": 0
    },
    "platform": {
      "platform": "win32",
      "nodeVersion": "v22.20.0",
      "environment": "development"
    },
    "uptime": 1234.567,
    "memory": {...},
    "timestamp": "2025-09-27T12:20:00.000Z"
  }
}
```

---

## 🔌 WebSocket Real-time Updates

Connect to WebSocket for live task progress and events.

### Connection
```javascript
const socket = io('http://localhost:3001');
```

### Subscribe to Task Updates
```javascript
// Subscribe to all task updates
socket.emit('subscribe_all_tasks');

// Subscribe to specific task
socket.emit('subscribe_task', 'task_1758975413313_1');

// Unsubscribe
socket.emit('unsubscribe_all_tasks');
socket.emit('unsubscribe_task', 'task_1758975413313_1');
```

### Event Listeners
```javascript
// Connection events
socket.on('connect', () => {
  console.log('Connected to Conductor Backend');
});

socket.on('welcome', (data) => {
  console.log('Welcome message:', data);
});

// Task events
socket.on('task_event', (event) => {
  console.log('Task event received:', event);
  // event.type: 'task_created', 'task_started', 'task_progress', 
  //             'task_completed', 'task_failed', 'task_cancelled'
  // event.taskId: Task identifier
  // event.timestamp: Event timestamp
  // event.data: Event-specific data
});

// System events
socket.on('system_event', (event) => {
  console.log('System event:', event);
});

// Health check
socket.emit('ping');
socket.on('pong', (data) => {
  console.log('Server responded:', data.timestamp);
});
```

---

## 📋 Task Status Reference

### Task States
- `"starting"` - Task is being initialized
- `"running"` - Task is actively executing
- `"waiting_approval"` - Task needs user approval to continue
- `"completed"` - Task finished successfully
- `"failed"` - Task failed with an error
- `"cancelled"` - Task was cancelled by user

### Approval Modes
- `"suggest"` - Interactive mode, requires approval for actions
- `"full-auto"` - Automatic execution with sandboxed file access
- `"danger"` - Full system access, bypasses all safety checks

### Exit Codes
- `0` - Success
- `1` - General error
- `2` - Misuse of shell builtins
- `-4058` - Authentication/subscription error

---

## 🛠️ Implementation Examples

### JavaScript/TypeScript Frontend

```javascript
class ConductorAPI {
  constructor(baseURL = 'http://localhost:3001') {
    this.baseURL = baseURL;
    this.socket = io(baseURL);
    this.setupWebSocket();
  }

  async createTask(prompt, options = {}) {
    const response = await fetch(`${this.baseURL}/api/tasks`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt,
        workingDir: options.workingDir,
        approvalMode: options.approvalMode || 'suggest'
      })
    });
    
    const result = await response.json();
    if (!result.success) {
      throw new Error(result.error);
    }
    
    return result.data;
  }

  async getTask(taskId) {
    const response = await fetch(`${this.baseURL}/api/tasks/${taskId}`);
    const result = await response.json();
    
    if (!result.success) {
      throw new Error(result.error);
    }
    
    return result.data;
  }

  async getAllTasks() {
    const response = await fetch(`${this.baseURL}/api/tasks`);
    const result = await response.json();
    
    if (!result.success) {
      throw new Error(result.error);
    }
    
    return result.data;
  }

  async approveTask(taskId, approved = true) {
    const response = await fetch(`${this.baseURL}/api/tasks/${taskId}/approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ approved })
    });
    
    const result = await response.json();
    if (!result.success) {
      throw new Error(result.error);
    }
    
    return result.data;
  }

  async cancelTask(taskId) {
    const response = await fetch(`${this.baseURL}/api/tasks/${taskId}`, {
      method: 'DELETE'
    });
    
    const result = await response.json();
    if (!result.success) {
      throw new Error(result.error);
    }
    
    return result.data;
  }

  setupWebSocket() {
    this.socket.on('connect', () => {
      console.log('Connected to Conductor Backend');
      this.socket.emit('subscribe_all_tasks');
    });

    this.socket.on('task_event', (event) => {
      this.onTaskEvent?.(event);
    });
  }

  onTaskEvent(callback) {
    this.onTaskEvent = callback;
  }
}

// Usage
const api = new ConductorAPI();

// Create task
const task = await api.createTask('organize my desktop files', {
  workingDir: '/Users/username/Desktop',
  approvalMode: 'suggest'
});

// Monitor progress
api.onTaskEvent((event) => {
  console.log(`Task ${event.taskId}: ${event.type}`);
  if (event.type === 'task_completed') {
    console.log('Task finished successfully!');
  }
});
```

### Swift (iOS/macOS)

```swift
import Foundation
import SocketIO

class ConductorAPI: ObservableObject {
    private let baseURL = "http://localhost:3001"
    private var socket: SocketIOClient
    
    @Published var tasks: [Task] = []
    @Published var isConnected = false
    
    init() {
        let manager = SocketManager(socketURL: URL(string: baseURL)!)
        self.socket = manager.defaultSocket
        setupWebSocket()
    }
    
    func createTask(prompt: String, workingDir: String? = nil, approvalMode: String = "suggest") async throws -> Task {
        let url = URL(string: "\(baseURL)/api/tasks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "prompt": prompt,
            "workingDir": workingDir,
            "approvalMode": approvalMode
        ].compactMapValues { $0 }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw APIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(APIResponse<Task>.self, from: data)
        return result.data
    }
    
    func getAllTasks() async throws -> [Task] {
        let url = URL(string: "\(baseURL)/api/tasks")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let result = try JSONDecoder().decode(APIResponse<[Task]>.self, from: data)
        DispatchQueue.main.async {
            self.tasks = result.data
        }
        return result.data
    }
    
    private func setupWebSocket() {
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.isConnected = true
            }
            self?.socket.emit("subscribe_all_tasks")
        }
        
        socket.on("task_event") { [weak self] data, ack in
            guard let eventData = data.first as? [String: Any] else { return }
            // Handle task event
            print("Task event: \(eventData)")
        }
        
        socket.connect()
    }
}

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let error: String?
}

struct Task: Codable, Identifiable {
    let id: String
    let prompt: String
    let workingDir: String?
    let approvalMode: String
    let status: String
    let startTime: String?
    let endTime: String?
    let exitCode: Int?
}
```

### Python Client

```python
import requests
import socketio
from typing import Optional, Dict, Any

class ConductorAPI:
    def __init__(self, base_url: str = "http://localhost:3001"):
        self.base_url = base_url
        self.sio = socketio.Client()
        self.setup_websocket()
    
    def create_task(self, prompt: str, working_dir: Optional[str] = None, 
                   approval_mode: str = "suggest") -> Dict[str, Any]:
        url = f"{self.base_url}/api/tasks"
        data = {
            "prompt": prompt,
            "approvalMode": approval_mode
        }
        if working_dir:
            data["workingDir"] = working_dir
            
        response = requests.post(url, json=data)
        response.raise_for_status()
        
        result = response.json()
        if not result["success"]:
            raise Exception(result["error"])
            
        return result["data"]
    
    def get_task(self, task_id: str) -> Dict[str, Any]:
        url = f"{self.base_url}/api/tasks/{task_id}"
        response = requests.get(url)
        response.raise_for_status()
        
        result = response.json()
        if not result["success"]:
            raise Exception(result["error"])
            
        return result["data"]
    
    def get_all_tasks(self) -> list:
        url = f"{self.base_url}/api/tasks"
        response = requests.get(url)
        response.raise_for_status()
        
        result = response.json()
        if not result["success"]:
            raise Exception(result["error"])
            
        return result["data"]
    
    def approve_task(self, task_id: str, approved: bool = True) -> Dict[str, Any]:
        url = f"{self.base_url}/api/tasks/{task_id}/approve"
        response = requests.post(url, json={"approved": approved})
        response.raise_for_status()
        
        result = response.json()
        if not result["success"]:
            raise Exception(result["error"])
            
        return result["data"]
    
    def cancel_task(self, task_id: str) -> Dict[str, Any]:
        url = f"{self.base_url}/api/tasks/{task_id}"
        response = requests.delete(url)
        response.raise_for_status()
        
        result = response.json()
        if not result["success"]:
            raise Exception(result["error"])
            
        return result["data"]
    
    def setup_websocket(self):
        @self.sio.event
        def connect():
            print("Connected to Conductor Backend")
            self.sio.emit('subscribe_all_tasks')
        
        @self.sio.event
        def task_event(data):
            print(f"Task event: {data}")
    
    def connect_websocket(self):
        self.sio.connect(self.base_url)
    
    def disconnect_websocket(self):
        self.sio.disconnect()

# Usage
api = ConductorAPI()

# Create and monitor task
task = api.create_task("list files in current directory")
print(f"Created task: {task['taskId']}")

# Connect to WebSocket for real-time updates
api.connect_websocket()

# Check task status
import time
time.sleep(5)
completed_task = api.get_task(task['taskId'])
print(f"Task status: {completed_task['status']}")
```

---

## 🔒 Security Considerations

### Development Mode
- No API key authentication required
- CORS enabled for localhost origins
- Full file system access with path validation

### Production Deployment
- Set `API_SECRET` environment variable
- Configure `CORS_ORIGINS` for your domains
- Use HTTPS in production
- Implement proper authentication layer

### File System Safety
- Paths are validated against safe directories
- Directory traversal attacks prevented
- OneDrive paths supported on Windows

---

## 🐛 Error Handling

### Common Error Responses
```json
{
  "success": false,
  "error": "Task not found"
}
```

### HTTP Status Codes
- `200` - Success
- `201` - Created (new task)
- `400` - Bad Request (validation error)
- `401` - Unauthorized (missing API key)
- `404` - Not Found (task/endpoint)
- `429` - Rate Limited
- `500` - Internal Server Error

### Rate Limits
- General API: 100 requests per 15 minutes
- Task creation: 20 requests per 5 minutes

---

## 📊 Monitoring & Analytics

### Health Monitoring
```javascript
// Check backend health
const health = await fetch('http://localhost:3001/health').then(r => r.json());
console.log('Backend health:', health.status);

// Get detailed system status
const status = await fetch('http://localhost:3001/api/system/status').then(r => r.json());
console.log('System stats:', status.data.tasks);
```

### WebSocket Statistics
```javascript
const wsStats = await fetch('http://localhost:3001/api/websocket/stats').then(r => r.json());
console.log('Connected clients:', wsStats.data.connectedClients);
```

---

## 🚀 Quick Test Commands

```bash
# Health check
curl http://localhost:3001/health

# Create simple task
curl -X POST http://localhost:3001/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"prompt": "list files in current directory"}'

# Get all tasks
curl http://localhost:3001/api/tasks

# Get specific task
curl http://localhost:3001/api/tasks/task_1758975413313_1

# System status
curl http://localhost:3001/api/system/status
```

---

**Ready to build amazing AI-powered applications with Conductor Backend!** 🎯

For questions or issues, check the main README.md or create an issue in the project repository.