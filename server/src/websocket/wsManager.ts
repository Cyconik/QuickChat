import { WebSocket, WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import { Database } from '../database/db';
import { MessageEnvelope, MessageReceipt, WsMessagePayload } from '../types';

const JWT_SECRET = process.env.JWT_SECRET || 'quickchat_mesh_secret_2026_production_key';
const db = Database.getInstance();

export class WebSocketManager {
  private wss: WebSocketServer;
  private userSockets: Map<string, Set<WebSocket>> = new Map(); // userId -> Set<WebSocket>
  private socketToUserId: Map<WebSocket, string> = new Map();

  constructor(wss: WebSocketServer) {
    this.wss = wss;
    this.init();
  }

  private init() {
    this.wss.on('connection', (ws: WebSocket, req) => {
      // Set ping interval
      (ws as any).isAlive = true;
      ws.on('pong', () => {
        (ws as any).isAlive = true;
      });

      ws.on('message', (raw: string) => {
        try {
          const payload: WsMessagePayload = JSON.parse(raw.toString());
          this.handlePayload(ws, payload);
        } catch (err: any) {
          this.send(ws, { event: 'error', data: { message: 'Malformed JSON payload' } });
        }
      });

      ws.on('close', () => {
        this.handleDisconnect(ws);
      });

      ws.on('error', (err) => {
        console.error('[WebSocket Error]', err);
      });
    });

    // Heartbeat check every 30s
    setInterval(() => {
      this.wss.clients.forEach((ws: WebSocket) => {
        if ((ws as any).isAlive === false) {
          this.handleDisconnect(ws);
          return ws.terminate();
        }
        (ws as any).isAlive = false;
        ws.ping();
      });
    }, 30000);
  }

  private handlePayload(ws: WebSocket, payload: WsMessagePayload) {
    switch (payload.event) {
      case 'auth':
        this.handleAuth(ws, payload.data);
        break;

      case 'message.send':
        this.handleSendMessage(ws, payload.data);
        break;

      case 'message.relayed':
      case 'message.delivered':
      case 'message.read':
        this.handleReceipt(ws, payload.event, payload.data);
        break;

      case 'sync.request':
        this.handleSync(ws);
        break;

      case 'ping':
        this.send(ws, { event: 'pong', data: { timestamp: Date.now() } });
        break;

      default:
        console.warn('Unknown WS event:', payload.event);
    }
  }

  private handleAuth(ws: WebSocket, data: { token: string }) {
    if (!data?.token) {
      this.send(ws, { event: 'error', data: { message: 'Token required for auth' } });
      return;
    }

    try {
      const decoded = jwt.verify(data.token, JWT_SECRET) as { userId: string };
      const userId = decoded.userId;

      this.socketToUserId.set(ws, userId);
      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId)!.add(ws);

      // Update online status in DB
      db.updateUser(userId, { isOnline: true });

      // Notify peer online
      this.broadcastPresence(userId, true);

      this.send(ws, {
        event: 'auth',
        data: { success: true, userId, message: 'Authenticated to QuickChat Cloud WebSocket' }
      });

      // Automatically flush pending offline messages
      this.handleSync(ws);
    } catch (err) {
      this.send(ws, { event: 'error', data: { message: 'Invalid token' } });
    }
  }

  private handleSendMessage(ws: WebSocket, envelope: MessageEnvelope) {
    const senderId = this.socketToUserId.get(ws);
    if (!senderId) {
      return this.send(ws, { event: 'error', data: { message: 'Unauthorized. Send auth event first.' } });
    }

    envelope.senderId = senderId;
    envelope.createdAt = envelope.createdAt || Date.now();

    const { isNew, message } = db.saveMessage(envelope);

    if (message.destinationType === 'user') {
      const targetUserId = message.destinationId;
      const targetSockets = this.userSockets.get(targetUserId);

      if (targetSockets && targetSockets.size > 0) {
        // Direct forward to online recipient
        for (const sock of targetSockets) {
          this.send(sock, { event: 'message.received', data: message });
        }
        // Notify sender of relayed/delivered
        this.send(ws, {
          event: 'message.delivered',
          data: { messageId: message.messageId, status: 'delivered', timestamp: Date.now() }
        });
      } else {
        // Recipient is offline on internet, store for store-and-forward sync
        db.queuePendingMessage(targetUserId, message.messageId);
        this.send(ws, {
          event: 'message.relayed',
          data: { messageId: message.messageId, status: 'relayed', timestamp: Date.now(), info: 'Stored in cloud queue' }
        });
      }
    } else if (message.destinationType === 'group') {
      const groupId = message.destinationId;
      const members = db.getGroupMembers(groupId);

      for (const member of members) {
        if (member.userId === senderId) continue;
        const memberSockets = this.userSockets.get(member.userId);
        if (memberSockets && memberSockets.size > 0) {
          for (const sock of memberSockets) {
            this.send(sock, { event: 'group.message', data: message });
          }
        } else {
          db.queuePendingMessage(member.userId, message.messageId);
        }
      }

      this.send(ws, {
        event: 'message.relayed',
        data: { messageId: message.messageId, status: 'relayed', timestamp: Date.now() }
      });
    }
  }

  private handleReceipt(ws: WebSocket, eventName: string, data: MessageReceipt) {
    const senderId = this.socketToUserId.get(ws);
    if (!senderId) return;

    data.recipientId = senderId;
    data.timestamp = Date.now();
    db.addReceipt(data);

    // Notify the original message sender if online
    const originalMsg = db.getMessage(data.messageId);
    if (originalMsg && originalMsg.senderId) {
      const senderSockets = this.userSockets.get(originalMsg.senderId);
      if (senderSockets) {
        for (const s of senderSockets) {
          this.send(s, { event: eventName as any, data });
        }
      }
    }
  }

  private handleSync(ws: WebSocket) {
    const userId = this.socketToUserId.get(ws);
    if (!userId) return;

    const pending = db.getAndClearPendingMessages(userId);
    if (pending.length > 0) {
      this.send(ws, {
        event: 'sync.response',
        data: { pendingMessages: pending, count: pending.length }
      });
    }
  }

  private handleDisconnect(ws: WebSocket) {
    const userId = this.socketToUserId.get(ws);
    if (userId) {
      const sockets = this.userSockets.get(userId);
      if (sockets) {
        sockets.delete(ws);
        if (sockets.size === 0) {
          this.userSockets.delete(userId);
          db.updateUser(userId, { isOnline: false, lastSeenAt: Date.now() });
          this.broadcastPresence(userId, false);
        }
      }
      this.socketToUserId.delete(ws);
    }
  }

  private broadcastPresence(userId: string, isOnline: boolean) {
    const event = isOnline ? 'peer.online' : 'peer.offline';
    const payload: WsMessagePayload = {
      event,
      data: { userId, timestamp: Date.now() }
    };
    const json = JSON.stringify(payload);

    this.wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(json);
      }
    });
  }

  private send(ws: WebSocket, payload: WsMessagePayload) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(payload));
    }
  }
}
