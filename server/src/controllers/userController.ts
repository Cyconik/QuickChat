import { Response } from 'express';
import { Database } from '../database/db';
import { AuthenticatedRequest } from '../middleware/auth';

const db = Database.getInstance();

export const getMe = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const user = db.getUserById(userId);
  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }
  return res.json({ success: true, user });
};

export const updateMe = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const { displayName, bio, avatarUrl, privacy } = req.body;

  const updated = db.updateUser(userId, {
    ...(displayName && { displayName: displayName.trim() }),
    ...(bio !== undefined && { bio: bio.trim() }),
    ...(avatarUrl !== undefined && { avatarUrl }),
    ...(privacy && { privacy }),
  });

  if (!updated) {
    return res.status(404).json({ error: 'User not found' });
  }

  return res.json({ success: true, user: updated });
};

export const getUserById = (req: AuthenticatedRequest, res: Response) => {
  const targetId = req.params.id;
  const user = db.getUserById(targetId);
  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }

  // Filter public profile based on privacy settings
  const publicProfile = {
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    publicKey: user.publicKey,
    bio: user.bio,
    avatarUrl: user.avatarUrl,
    isOnline: user.privacy.showOnlineStatus ? user.isOnline : undefined,
    lastSeenAt: user.privacy.showOnlineStatus ? user.lastSeenAt : undefined,
    privacy: {
      allowRelay: user.privacy.allowRelay
    }
  };

  return res.json({ success: true, user: publicProfile });
};

export const getNearbyUsers = (req: AuthenticatedRequest, res: Response) => {
  const currentUserId = req.userId;
  const allUsers = db.getAllUsers();

  // Return online or recently seen users who permit discovery
  const nearby = allUsers
    .filter(u => u.id !== currentUserId)
    .filter(u => u.privacy.discoverableBy !== 'nobody')
    .map(u => ({
      id: u.id,
      username: u.username,
      displayName: u.displayName,
      publicKey: u.publicKey,
      bio: u.bio,
      avatarUrl: u.avatarUrl,
      isOnline: u.privacy.showOnlineStatus ? u.isOnline : false,
      lastSeenAt: u.lastSeenAt,
      signalEstimate: 'approximate_nearby'
    }));

  return res.json({ success: true, nearby });
};
