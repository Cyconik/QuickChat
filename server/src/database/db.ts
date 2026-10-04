import { User, Group, GroupMember, MessageEnvelope, Connection, MessageReceipt } from '../types';

export class Database {
  private static instance: Database;

  public users: Map<string, User> = new Map();
  public usersByUsername: Map<string, string> = new Map(); // username -> userId
  public groups: Map<string, Group> = new Map();
  public groupMembers: Map<string, GroupMember[]> = new Map(); // groupId -> GroupMember[]
  public userGroups: Map<string, Set<string>> = new Map(); // userId -> Set<groupId>
  public messages: Map<string, MessageEnvelope> = new Map(); // messageId -> MessageEnvelope
  public conversationMessages: Map<string, string[]> = new Map(); // convId -> messageId[]
  public pendingOfflineMessages: Map<string, string[]> = new Map(); // userId -> messageId[]
  public connections: Map<string, Connection> = new Map(); // connectionId -> Connection
  public seenMessageIds: Set<string> = new Set(); // deduplication cache
  public messageReceipts: Map<string, MessageReceipt[]> = new Map(); // messageId -> MessageReceipt[]

  private constructor() {
    this.seedDefaultGroups();
  }

  public static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  private seedDefaultGroups() {
    const defaultGroups: Group[] = [
      {
        id: 'group_tech_delhi',
        name: 'Delhi Tech Community',
        description: 'Decentralized peer-to-peer discussions for developers and creators in Delhi.',
        privacy: 'public',
        category: 'technology',
        creatorId: 'usr_system',
        createdAt: Date.now() - 86400000 * 7,
        memberCount: 142
      },
      {
        id: 'group_mesh_builders',
        name: 'Mesh Network Engineers',
        description: 'Global ad-hoc multi-hop mesh protocol discussions & testing.',
        privacy: 'public',
        category: 'technology',
        creatorId: 'usr_system',
        createdAt: Date.now() - 86400000 * 14,
        memberCount: 88
      },
      {
        id: 'group_local_events',
        name: 'Nearby Events & Meetups',
        description: 'Discover local events happening in proximity right now.',
        privacy: 'public',
        category: 'events',
        creatorId: 'usr_system',
        createdAt: Date.now() - 86400000 * 3,
        memberCount: 65
      }
    ];

    for (const g of defaultGroups) {
      this.groups.set(g.id, g);
      this.groupMembers.set(g.id, []);
    }
  }

  // User Operations
  public createUser(user: User): User {
    this.users.set(user.id, user);
    this.usersByUsername.set(user.username.toLowerCase(), user.id);
    return user;
  }

  public getUserById(id: string): User | undefined {
    return this.users.get(id);
  }

  public getUserByUsername(username: string): User | undefined {
    const id = this.usersByUsername.get(username.toLowerCase());
    if (!id) return undefined;
    return this.users.get(id);
  }

  public updateUser(id: string, updates: Partial<User>): User | undefined {
    const user = this.users.get(id);
    if (!user) return undefined;
    const updated = { ...user, ...updates, lastSeenAt: Date.now() };
    this.users.set(id, updated);
    return updated;
  }

  public getAllUsers(): User[] {
    return Array.from(this.users.values());
  }

  // Group Operations
  public createGroup(group: Group, creatorId: string): Group {
    this.groups.set(group.id, group);
    const member: GroupMember = {
      groupId: group.id,
      userId: creatorId,
      role: 'admin',
      joinedAt: Date.now()
    };
    this.groupMembers.set(group.id, [member]);
    
    if (!this.userGroups.has(creatorId)) {
      this.userGroups.set(creatorId, new Set());
    }
    this.userGroups.get(creatorId)!.add(group.id);
    return group;
  }

  public getGroupById(groupId: string): Group | undefined {
    return this.groups.get(groupId);
  }

  public getGroups(): Group[] {
    return Array.from(this.groups.values());
  }

  public joinGroup(groupId: string, userId: string): boolean {
    const group = this.groups.get(groupId);
    if (!group) return false;

    const members = this.groupMembers.get(groupId) || [];
    if (members.some(m => m.userId === userId)) return true;

    members.push({
      groupId,
      userId,
      role: 'member',
      joinedAt: Date.now()
    });
    this.groupMembers.set(groupId, members);
    group.memberCount = members.length;

    if (!this.userGroups.has(userId)) {
      this.userGroups.set(userId, new Set());
    }
    this.userGroups.get(userId)!.add(groupId);
    return true;
  }

  public leaveGroup(groupId: string, userId: string): boolean {
    const group = this.groups.get(groupId);
    if (!group) return false;

    let members = this.groupMembers.get(groupId) || [];
    members = members.filter(m => m.userId !== userId);
    this.groupMembers.set(groupId, members);
    group.memberCount = members.length;

    if (this.userGroups.has(userId)) {
      this.userGroups.get(userId)!.delete(groupId);
    }
    return true;
  }

  public getGroupMembers(groupId: string): GroupMember[] {
    return this.groupMembers.get(groupId) || [];
  }

  public getUserGroups(userId: string): Group[] {
    const groupIds = this.userGroups.get(userId) || new Set();
    const result: Group[] = [];
    for (const gId of groupIds) {
      const g = this.groups.get(gId);
      if (g) result.push(g);
    }
    return result;
  }

  // Message Operations
  public saveMessage(message: MessageEnvelope): { isNew: boolean; message: MessageEnvelope } {
    if (this.seenMessageIds.has(message.messageId)) {
      return { isNew: false, message: this.messages.get(message.messageId) || message };
    }

    this.seenMessageIds.add(message.messageId);
    this.messages.set(message.messageId, message);

    const convId = message.conversationId;
    if (!this.conversationMessages.has(convId)) {
      this.conversationMessages.set(convId, []);
    }
    this.conversationMessages.get(convId)!.push(message.messageId);

    return { isNew: true, message };
  }

  public getMessage(messageId: string): MessageEnvelope | undefined {
    return this.messages.get(messageId);
  }

  public getConversationMessages(convId: string, limit = 50): MessageEnvelope[] {
    const msgIds = this.conversationMessages.get(convId) || [];
    const slice = msgIds.slice(-limit);
    const result: MessageEnvelope[] = [];
    for (const id of slice) {
      const msg = this.messages.get(id);
      if (msg) result.push(msg);
    }
    return result;
  }

  public queuePendingMessage(recipientId: string, messageId: string) {
    if (!this.pendingOfflineMessages.has(recipientId)) {
      this.pendingOfflineMessages.set(recipientId, []);
    }
    const list = this.pendingOfflineMessages.get(recipientId)!;
    if (!list.includes(messageId)) {
      list.push(messageId);
    }
  }

  public getAndClearPendingMessages(recipientId: string): MessageEnvelope[] {
    const msgIds = this.pendingOfflineMessages.get(recipientId) || [];
    this.pendingOfflineMessages.delete(recipientId);
    const result: MessageEnvelope[] = [];
    for (const id of msgIds) {
      const msg = this.messages.get(id);
      if (msg) result.push(msg);
    }
    return result;
  }

  public addReceipt(receipt: MessageReceipt) {
    if (!this.messageReceipts.has(receipt.messageId)) {
      this.messageReceipts.set(receipt.messageId, []);
    }
    this.messageReceipts.get(receipt.messageId)!.push(receipt);

    const msg = this.messages.get(receipt.messageId);
    if (msg) {
      if (receipt.status === 'read') {
        msg.status = 'read';
      } else if (receipt.status === 'delivered' && msg.status !== 'read') {
        msg.status = 'delivered';
      } else if (receipt.status === 'relayed' && msg.status === 'sent') {
        msg.status = 'relayed';
      }
    }
  }

  // Connection Operations
  public createOrUpdateConnection(requesterId: string, targetId: string, status: 'requested' | 'accepted' | 'rejected' | 'blocked'): Connection {
    const key = [requesterId, targetId].sort().join(':');
    const existing = this.connections.get(key);
    const conn: Connection = {
      id: existing ? existing.id : `conn_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      requesterId,
      targetId,
      status,
      createdAt: existing ? existing.createdAt : Date.now(),
      updatedAt: Date.now()
    };
    this.connections.set(key, conn);
    return conn;
  }

  public getUserConnections(userId: string): Connection[] {
    const result: Connection[] = [];
    for (const conn of this.connections.values()) {
      if (conn.requesterId === userId || conn.targetId === userId) {
        result.push(conn);
      }
    }
    return result;
  }
}
