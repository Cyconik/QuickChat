import { Request, Response } from 'express';
import { Database } from '../database/db';
import { generateToken } from '../middleware/auth';
import { User } from '../types';

const db = Database.getInstance();

export const registerAnonymous = (req: Request, res: Response) => {
  try {
    const { username, displayName, publicKey, bio, avatarUrl, privacy } = req.body;

    if (!username || !displayName || !publicKey) {
      return res.status(400).json({ error: 'Username, displayName, and publicKey are required' });
    }

    const cleanUsername = username.trim().toLowerCase().replace(/[^a-z0-9_]/g, '');
    if (cleanUsername.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters alphanumeric' });
    }

    // Check if username already exists
    const existing = db.getUserByUsername(cleanUsername);
    if (existing) {
      return res.status(409).json({ error: 'Username already taken. Please choose another.' });
    }

    // Generate unique user ID: usr_XXXXXX
    const randomHex = Math.random().toString(16).substring(2, 8).toUpperCase();
    const userId = `usr_${randomHex}`;

    const newUser: User = {
      id: userId,
      username: cleanUsername,
      displayName: displayName.trim(),
      publicKey: publicKey.trim(),
      bio: bio || 'Participating in QuickChat mesh.',
      avatarUrl: avatarUrl || undefined,
      createdAt: Date.now(),
      lastSeenAt: Date.now(),
      isOnline: true,
      privacy: {
        discoverableBy: privacy?.discoverableBy || 'everyone',
        messageableBy: privacy?.messageableBy || 'everyone',
        showOnlineStatus: privacy?.showOnlineStatus !== false,
        showNearbyPresence: privacy?.showNearbyPresence !== false,
        allowRelay: privacy?.allowRelay !== false,
      }
    };

    db.createUser(newUser);
    const token = generateToken(userId);

    return res.status(201).json({
      success: true,
      token,
      user: newUser
    });
  } catch (error: any) {
    return res.status(500).json({ error: error.message || 'Registration failed' });
  }
};

export const loginWithKey = (req: Request, res: Response) => {
  try {
    const { userId, signature, challenge } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const user = db.getUserById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Update status
    db.updateUser(userId, { isOnline: true });
    const token = generateToken(userId);

    return res.json({
      success: true,
      token,
      user
    });
  } catch (error: any) {
    return res.status(500).json({ error: error.message || 'Login failed' });
  }
};
