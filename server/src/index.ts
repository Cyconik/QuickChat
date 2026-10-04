import express from 'express';
import http from 'http';
import { WebSocketServer } from 'ws';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';

import { registerAnonymous, loginWithKey } from './controllers/authController';
import { getMe, updateMe, getUserById, getNearbyUsers } from './controllers/userController';
import { getConnections, updateConnectionStatus } from './controllers/connectionController';
import { getGroups, createGroup, joinGroup, leaveGroup, getGroupMembers } from './controllers/groupController';
import { getConversationMessages, syncOfflineMessages, postMessageFallback, postReceipt } from './controllers/chatController';
import { authenticateToken } from './middleware/auth';
import { WebSocketManager } from './websocket/wsManager';

dotenv.config();

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// Security & Middleware
app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '10mb' }));

// Anti-spam Rate Limiter
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  message: { error: 'Too many requests from this IP, please try again later.' }
});
app.use('/api/', apiLimiter);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ONLINE',
    service: 'QuickChat Mesh & Cloud Hybrid Gateway',
    timestamp: Date.now(),
    version: '1.0.0'
  });
});

// Auth Routes
app.post('/api/auth/register', registerAnonymous);
app.post('/api/auth/login', loginWithKey);

// User Routes
app.get('/api/users/me', authenticateToken, getMe);
app.put('/api/users/me', authenticateToken, updateMe);
app.get('/api/users/nearby', authenticateToken, getNearbyUsers);
app.get('/api/users/:id', authenticateToken, getUserById);

// Connection Routes
app.get('/api/connections', authenticateToken, getConnections);
app.post('/api/connections', authenticateToken, updateConnectionStatus);

// Group Routes
app.get('/api/groups', authenticateToken, getGroups);
app.post('/api/groups', authenticateToken, createGroup);
app.post('/api/groups/:id/join', authenticateToken, joinGroup);
app.post('/api/groups/:id/leave', authenticateToken, leaveGroup);
app.get('/api/groups/:id/members', authenticateToken, getGroupMembers);

// Chat & Message Routes
app.get('/api/conversations/:id/messages', authenticateToken, getConversationMessages);
app.get('/api/sync/offline', authenticateToken, syncOfflineMessages);
app.post('/api/messages/fallback', authenticateToken, postMessageFallback);
app.post('/api/messages/receipt', authenticateToken, postReceipt);

// WebSocket Server
const wss = new WebSocketServer({ server, path: '/ws' });
new WebSocketManager(wss);

server.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(` QuickChat Mesh & Cloud Gateway Server`);
  console.log(` HTTP REST:   http://localhost:${PORT}`);
  console.log(` WebSocket:   ws://localhost:${PORT}/ws`);
  console.log(` Health:      http://localhost:${PORT}/health`);
  console.log(` Status:      ACTIVE`);
  console.log(`=======================================================`);
});
