import { Response } from 'express';
import { Database } from '../database/db';
import { AuthenticatedRequest } from '../middleware/auth';

const db = Database.getInstance();

export const getConnections = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const connections = db.getUserConnections(userId);

  // Hydrate with user details
  const hydrated = connections.map(conn => {
    const otherUserId = conn.requesterId === userId ? conn.targetId : conn.requesterId;
    const otherUser = db.getUserById(otherUserId);
    return {
      ...conn,
      otherUser: otherUser ? {
        id: otherUser.id,
        username: otherUser.username,
        displayName: otherUser.displayName,
        publicKey: otherUser.publicKey,
        avatarUrl: otherUser.avatarUrl,
        isOnline: otherUser.isOnline
      } : null
    };
  });

  return res.json({ success: true, connections: hydrated });
};

export const updateConnectionStatus = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const { targetId, status } = req.body;

  if (!targetId || !status) {
    return res.status(400).json({ error: 'targetId and status are required' });
  }

  if (!['requested', 'accepted', 'rejected', 'blocked'].includes(status)) {
    return res.status(400).json({ error: 'Invalid connection status' });
  }

  const targetUser = db.getUserById(targetId);
  if (!targetUser) {
    return res.status(404).json({ error: 'Target user does not exist' });
  }

  const conn = db.createOrUpdateConnection(userId, targetId, status);
  return res.json({ success: true, connection: conn });
};
