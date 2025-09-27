# Postman Testing Guide - Conductor Backend API

This guide provides step-by-step instructions for testing the Conductor Backend API using Postman.

## 🚀 Setup

### 1. Start the Backend Server
```bash
cd "C:\Users\savbo\OneDrive\Desktop\Conductor\Backend"
npm run dev
```

Wait for the server to start. You should see:
```
🚀 Conductor Backend running on http://localhost:3001
📊 Health check: http://localhost:3001/health
🔌 WebSocket: ws://localhost:3001
📝 API Docs: http://localhost:3001/api
```

### 2. Postman Configuration
- **Base URL:** `http://localhost:3001`
- **No authentication required** in development mode
- **Content-Type:** `application/json` for POST requests

---

## 📡 API Endpoints Testing

### 1. Health Check
**Test server connectivity and status**

- **Method:** `GET`
- **URL:** `http://localhost:3001/health`
- **Headers:** None required

**Expected Response:**
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

---

### 2. Create New Task
**Submit a task for Codex CLI execution**

- **Method:** `POST`
- **URL:** `http://localhost:3001/api/tasks`
- **Headers:** 
  - `Content-Type: application/json`

**Body (raw JSON):**
```json
{
  "prompt": "list files in current directory",
  "approvalMode": "suggest"
}
```

**Alternative Bodies:**

*Desktop organization task:*
```json
{
  "prompt": "organize the files on my desktop by creating logical folder structures",
  "workingDir": "C:/Users/savbo/OneDrive/Desktop",
  "approvalMode": "danger"
}
```

*Simple file listing:*
```json
{
  "prompt": "what files are in this directory?",
  "approvalMode": "suggest"
}
```

*Code analysis task:*
```json
{
  "prompt": "analyze the JavaScript files in this project and suggest improvements",
  "workingDir": "C:/Users/savbo/OneDrive/Desktop/Conductor/Backend",
  "approvalMode": "suggest"
}
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "taskId": "task_1758975413313_1",
    "status": "running",
    "prompt": "list files in current directory"
  }
}
```

**Save the `taskId` for subsequent requests!**

---

### 3. Get All Tasks
**Retrieve list of all tasks**

- **Method:** `GET`
- **URL:** `http://localhost:3001/api/tasks`
- **Headers:** None required

**Expected Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "task_1758975413313_1",
      "prompt": "list files in current directory",
      "workingDir": "C:\\Users\\savbo\\OneDrive\\Desktop\\Conductor\\Backend",
      "approvalMode": "suggest",
      "status": "completed",
      "startTime": "2025-09-27T12:16:53.313Z",
      "endTime": "2025-09-27T12:16:58.812Z",
      "exitCode": 0,
      "logs": [...],
      "processId": 38604
    }
  ],
  "count": 1
}
```

---

### 4. Get Specific Task
**Retrieve detailed information for a specific task**

- **Method:** `GET`
- **URL:** `http://localhost:3001/api/tasks/{taskId}`
- **Replace `{taskId}` with actual task ID from previous response**

**Example URL:**
```
http://localhost:3001/api/tasks/task_1758975413313_1
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "id": "task_1758975413313_1",
    "prompt": "list files in current directory",
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

---

### 5. Get Task Logs
**Retrieve logs for a specific task**

- **Method:** `GET`
- **URL:** `http://localhost:3001/api/tasks/{taskId}/logs`

**Example URL:**
```
http://localhost:3001/api/tasks/task_1758975413313_1/logs
```

**Expected Response:**
```json
{
  "success": true,
  "data": [
    {
      "timestamp": "2025-09-27T12:16:53.774Z",
      "type": "stderr",
      "message": "The existing `--json` output format is being deprecated..."
    },
    {
      "timestamp": "2025-09-27T12:16:57.318Z",
      "type": "stdout",
      "message": "Codex CLI output..."
    }
  ]
}
```

---

### 6. Approve Pending Task
**Approve or reject a task waiting for approval**

- **Method:** `POST`
- **URL:** `http://localhost:3001/api/tasks/{taskId}/approve`
- **Headers:** 
  - `Content-Type: application/json`

**Body (raw JSON) - Approve:**
```json
{
  "approved": true
}
```

**Body (raw JSON) - Reject:**
```json
{
  "approved": false
}
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "id": "task_1758975413313_1",
    "status": "running",
    ...
  }
}
```

---

### 7. Cancel Task
**Cancel a running or pending task**

- **Method:** `DELETE`
- **URL:** `http://localhost:3001/api/tasks/{taskId}`
- **Headers:** None required

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "id": "task_1758975413313_1",
    "status": "cancelled",
    "endTime": "2025-09-27T12:20:00.000Z"
  }
}
```

---

### 8. System Status
**Get detailed system information and statistics**

- **Method:** `GET`
- **URL:** `http://localhost:3001/api/system/status`
- **Headers:** None required

**Expected Response:**
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
      "workingDirectory": "C:\\Users\\savbo\\OneDrive\\Desktop\\Conductor\\Backend",
      "homeDirectory": "C:\\Users\\savbo",
      "environment": "development",
      "codexCommand": "codex.exe",
      "codexConfigPath": "C:\\Users\\savbo\\.codex"
    },
    "uptime": 1234.567,
    "memory": {
      "rss": 45678912,
      "heapTotal": 25165824,
      "heapUsed": 18456789,
      "external": 1234567,
      "arrayBuffers": 123456
    },
    "timestamp": "2025-09-27T12:20:00.000Z"
  }
}
```

---

### 9. System Configuration
**Get backend configuration information**

- **Method:** `GET`
- **URL:** `http://localhost:3001/api/system/config`
- **Headers:** None required

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "platform": "win32",
    "nodeVersion": "v22.20.0",
    "environment": "development",
    "mockMode": false,
    "codexPath": "codex.exe",
    "configPath": "C:\\Users\\savbo\\.codex",
    "corsEnabled": true
  }
}
```

---

### 10. WebSocket Statistics
**Get WebSocket connection statistics**

- **Method:** `GET`
- **URL:** `http://localhost:3001/api/websocket/stats`
- **Headers:** None required

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "connectedClients": 2,
    "rooms": ["all_tasks", "task:task_1758975413313_1"],
    "uptime": 1234.567
  }
}
```

---

### 11. Database Statistics
**Get database statistics and metrics**

- **Method:** `GET`
- **URL:** `http://localhost:3001/api/database/stats`
- **Headers:** None required

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "total_tasks": 10,
    "active_tasks": 2,
    "completed_tasks": 7,
    "failed_tasks": 1,
    "total_logs": 156,
    "active_sessions": 1
  }
}
```

---

## 🧪 Testing Workflows

### Workflow 1: Basic Task Execution
1. **Health Check** - Verify server is running
2. **Create Task** - Submit a simple task
3. **Monitor Task** - Check task status every few seconds
4. **Get Logs** - View execution logs when complete

### Workflow 2: Task Management
1. **Create Multiple Tasks** - Submit several tasks
2. **Get All Tasks** - View task list
3. **Cancel Task** - Cancel one running task
4. **System Status** - Check overall statistics

### Workflow 3: Approval Workflow
1. **Create Task with "suggest" mode** - Task requiring approval
2. **Monitor Task** - Wait for "waiting_approval" status
3. **Approve Task** - Send approval
4. **Monitor Completion** - Wait for completion

### Workflow 4: Error Handling
1. **Invalid Task** - Send malformed JSON
2. **Missing Task** - Request non-existent task ID
3. **Invalid Approval** - Try to approve completed task

---

## 📋 Postman Collection Setup

### Create Collection
1. **New Collection** → "Conductor Backend API"
2. **Variables:**
   - `baseUrl`: `http://localhost:3001`
   - `taskId`: `{{taskId}}` (will be set from responses)

### Environment Variables
Create a new environment with:
- `baseUrl`: `http://localhost:3001`
- `currentTaskId`: (leave empty, will be populated)

### Request Templates

**Health Check:**
```
GET {{baseUrl}}/health
```

**Create Task:**
```
POST {{baseUrl}}/api/tasks
Content-Type: application/json

{
  "prompt": "{{prompt}}",
  "approvalMode": "suggest"
}
```

**Get Task:**
```
GET {{baseUrl}}/api/tasks/{{currentTaskId}}
```

### Post-request Scripts
Add to "Create Task" request:
```javascript
// Save task ID for subsequent requests
if (pm.response.code === 201) {
    const response = pm.response.json();
    pm.environment.set("currentTaskId", response.data.taskId);
}
```

---

## 🔍 Common Response Patterns

### Success Response
```json
{
  "success": true,
  "data": { ... }
}
```

### Error Response
```json
{
  "success": false,
  "error": "Error message description"
}
```

### Task Status Values
- `"starting"` - Task initialization
- `"running"` - Task executing
- `"waiting_approval"` - Needs user approval
- `"completed"` - Finished successfully
- `"failed"` - Error occurred
- `"cancelled"` - User cancelled

### HTTP Status Codes
- `200` - Success
- `201` - Created (new task)
- `400` - Bad Request
- `404` - Not Found
- `429` - Rate Limited
- `500` - Server Error

---

## 🐛 Troubleshooting

### Server Not Responding
1. Check if server is running: `npm run dev`
2. Verify URL: `http://localhost:3001`
3. Check firewall settings
4. Try health check endpoint first

### Task Creation Fails
1. Verify JSON format
2. Check required fields: `prompt`
3. Validate `approvalMode` values
4. Check working directory permissions

### Task Stuck in "running"
1. Check server console for errors
2. Verify Codex CLI is installed
3. Check ChatGPT Plus subscription
4. Try cancelling and recreating

### Empty Response
1. Check `Content-Type` header
2. Verify request method (GET/POST/DELETE)
3. Check endpoint spelling
4. Ensure server is in development mode

---

## 🎯 Testing Checklist

### Basic Functionality
- [ ] Health check returns "healthy"
- [ ] Can create simple task
- [ ] Task executes and completes
- [ ] Can retrieve task by ID
- [ ] Can get all tasks list

### Task Management
- [ ] Can create task with custom working directory
- [ ] Can create task with different approval modes
- [ ] Can cancel running task
- [ ] Can approve pending task

### System Monitoring
- [ ] System status shows correct information
- [ ] WebSocket stats show connections
- [ ] Database stats show task counts
- [ ] Configuration shows correct settings

### Error Handling
- [ ] Invalid JSON returns 400 error
- [ ] Missing task ID returns 404 error
- [ ] Malformed requests handled gracefully
- [ ] Server errors return proper error messages

---

**Happy Testing! 🚀**

Use this guide to thoroughly test the Conductor Backend API with Postman. All endpoints are ready for integration with your frontend applications.