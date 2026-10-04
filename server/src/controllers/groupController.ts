import { Response } from 'express';
import { Database } from '../database/db';
import { AuthenticatedRequest } from '../middleware/auth';
import { Group } from '../types';

const db = Database.getInstance();

export const getGroups = (req: AuthenticatedRequest, res: Response) => {
  const { category, search } = req.query;
  let groups = db.getGroups();

  if (category && typeof category === 'string') {
    groups = groups.filter(g => g.category.toLowerCase() === category.toLowerCase());
  }

  if (search && typeof search === 'string') {
    const q = search.toLowerCase();
    groups = groups.filter(g => g.name.toLowerCase().includes(q) || g.description.toLowerCase().includes(q));
  }

  return res.json({ success: true, groups });
};

export const createGroup = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const { name, description, category, privacy, avatarUrl } = req.body;

  if (!name || name.trim().length === 0) {
    return res.status(400).json({ error: 'Group name is required' });
  }

  const groupId = `group_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 6)}`;

  const newGroup: Group = {
    id: groupId,
    name: name.trim(),
    description: description ? description.trim() : '',
    category: category || 'general',
    privacy: privacy || 'public',
    avatarUrl,
    creatorId: userId,
    createdAt: Date.now(),
    memberCount: 1
  };

  db.createGroup(newGroup, userId);

  return res.status(201).json({ success: true, group: newGroup });
};

export const joinGroup = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const groupId = req.params.id;

  const group = db.getGroupById(groupId);
  if (!group) {
    return res.status(404).json({ error: 'Group not found' });
  }

  const success = db.joinGroup(groupId, userId);
  return res.json({ success, message: 'Joined group successfully' });
};

export const leaveGroup = (req: AuthenticatedRequest, res: Response) => {
  const userId = req.userId!;
  const groupId = req.params.id;

  const success = db.leaveGroup(groupId, userId);
  return res.json({ success, message: 'Left group successfully' });
};

export const getGroupMembers = (req: AuthenticatedRequest, res: Response) => {
  const groupId = req.params.id;
  const members = db.getGroupMembers(groupId);

  const hydrated = members.map(m => {
    const u = db.getUserById(m.userId);
    return {
      ...m,
      user: u ? {
        id: u.id,
        username: u.username,
        displayName: u.displayName,
        avatarUrl: u.avatarUrl,
        isOnline: u.isOnline
      } : null
    };
  });

  return res.json({ success: true, members: hydrated });
};
