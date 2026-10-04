import { Response } from 'express';
import { Database } from '../database/db';
import { AuthenticatedRequest } from '../middleware/auth';
import { MessageEnvelope, MessageReceipt } from '../types';

const db = Database.getInstance();

export const getConversationMessages = (req: AuthenticatedRequest, res: Response) => {
  const convId = req.params.id;
  const limit = parseInt(req.query.limit as string, 10) || 50;

  const messages = db.getConversationMessages(convId, limit);
  return res.json({ success: true, messages });
};

export const syncOfflineMessages = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const pending = db.getAndClearPendingMessages(userId);
  return res.json({ success: true, pendingMessages: pending });
};

export const postMessageFallback = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const messageData = req.body as MessageEnvelope;

  if (!messageData || !messageData.messageId || !messageData.encryptedPayload) {
    return res.status(400).json({ error: 'Valid MessageEnvelope is required' });
  }

  // Enforce sender integrity
  messageData.senderId = userId;
  messageData.createdAt = messageData.createdAt || Date.now();

  const { isNew, message } = db.saveMessage(messageData);

  // If destination is user and user is offline, queue
  if (message.destinationType === 'user') {
    const recipient = db.getUserById(message.destinationId);
    if (recipient && !recipient.isOnline) {
      db.queuePendingMessage(message.destinationId, message.messageId);
    }
  }

  return res.json({ success: true, isNew, message });
};

export const postReceipt = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const receipt = req.body as MessageReceipt;

  if (!receipt || !receipt.messageId || !receipt.status) {
    return res.status(400).json({ error: 'Valid MessageReceipt is required' });
  }

  receipt.recipientId = userId;
  receipt.timestamp = Date.now();

  db.addReceipt(receipt);
  return res.json({ success: true, receipt });
};
