export interface User {
  id: string; // e.g. usr_8F92A1
  username: string; // e.g. anonymousfox
  displayName: string; // e.g. Anonymous Fox
  publicKey: string; // Base64 encoded Ed25519/ECDH public key
  bio: string;
  avatarUrl?: string;
  createdAt: number;
  lastSeenAt: number;
  isOnline: boolean;
  privacy: UserPrivacy;
}

export interface UserPrivacy {
  discoverableBy: 'everyone' | 'nearby_only' | 'connections_only' | 'nobody';
  messageableBy: 'everyone' | 'connections_only' | 'nobody';
  showOnlineStatus: boolean;
  showNearbyPresence: boolean;
  allowRelay: boolean;
}

export interface Connection {
  id: string;
  requesterId: string;
  targetId: string;
  status: 'requested' | 'accepted' | 'rejected' | 'blocked';
  createdAt: number;
  updatedAt: number;
}

export interface Group {
  id: string; // e.g. group_1234
  name: string;
  description: string;
  avatarUrl?: string;
  privacy: 'public' | 'private' | 'invite_only';
  category: 'technology' | 'college' | 'events' | 'local' | 'gaming' | 'study' | 'business' | 'general';
  creatorId: string;
  createdAt: number;
  memberCount: number;
}

export interface GroupMember {
  groupId: string;
  userId: string;
  role: 'admin' | 'moderator' | 'member';
  joinedAt: number;
}

export interface MessageEnvelope {
  messageId: string; // msg_123456
  senderId: string; // usr_123
  senderUsername?: string;
  conversationId: string; // conv_456
  messageType: 'text' | 'image' | 'file' | 'system' | 'ack';
  createdAt: number;
  ttl: number; // e.g. 8
  hopCount: number; // e.g. 0
  destinationType: 'user' | 'group';
  destinationId: string; // usr_789 or group_123
  encryptedPayload: string; // E2E encrypted payload (Base64)
  signature: string; // Cryptographic signature from sender (Base64)
  relayPath?: string[]; // IDs of nodes that relayed this message
  status?: 'pending' | 'sent' | 'relayed' | 'delivered' | 'read';
}

export interface MessageReceipt {
  receiptId: string;
  messageId: string;
  recipientId: string;
  status: 'relayed' | 'delivered' | 'read';
  timestamp: number;
  signature: string;
}

export interface Conversation {
  id: string;
  type: 'direct' | 'group';
  targetId: string; // other userId or groupId
  lastMessage?: MessageEnvelope;
  unreadCount: number;
  updatedAt: number;
}

export interface WsMessagePayload {
  event:
    | 'auth'
    | 'message.send'
    | 'message.received'
    | 'message.relayed'
    | 'message.delivered'
    | 'message.read'
    | 'peer.online'
    | 'peer.offline'
    | 'group.message'
    | 'sync.request'
    | 'sync.response'
    | 'ping'
    | 'pong'
    | 'error';
  data: any;
}
