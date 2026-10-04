-- PostgreSQL Schema for QuickChat Mesh & Cloud Platform

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    username VARCHAR(32) UNIQUE NOT NULL,
    display_name VARCHAR(64) NOT NULL,
    public_key TEXT NOT NULL,
    bio TEXT DEFAULT '',
    avatar_url TEXT,
    created_at BIGINT NOT NULL,
    last_seen_at BIGINT NOT NULL,
    is_online BOOLEAN DEFAULT FALSE,
    privacy_discoverable_by VARCHAR(32) DEFAULT 'everyone',
    privacy_messageable_by VARCHAR(32) DEFAULT 'everyone',
    privacy_show_online BOOLEAN DEFAULT TRUE,
    privacy_show_nearby BOOLEAN DEFAULT TRUE,
    privacy_allow_relay BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS groups (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    avatar_url TEXT,
    privacy VARCHAR(32) DEFAULT 'public',
    category VARCHAR(32) DEFAULT 'general',
    creator_id VARCHAR(64) REFERENCES users(id),
    created_at BIGINT NOT NULL,
    member_count INT DEFAULT 1
);

CREATE TABLE IF NOT EXISTS group_members (
    group_id VARCHAR(64) REFERENCES groups(id) ON DELETE CASCADE,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(32) DEFAULT 'member',
    joined_at BIGINT NOT NULL,
    PRIMARY KEY (group_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
    message_id VARCHAR(64) PRIMARY KEY,
    sender_id VARCHAR(64) REFERENCES users(id),
    conversation_id VARCHAR(64) NOT NULL,
    message_type VARCHAR(32) DEFAULT 'text',
    created_at BIGINT NOT NULL,
    ttl INT DEFAULT 8,
    hop_count INT DEFAULT 0,
    destination_type VARCHAR(32) NOT NULL,
    destination_id VARCHAR(64) NOT NULL,
    encrypted_payload TEXT NOT NULL,
    signature TEXT NOT NULL,
    status VARCHAR(32) DEFAULT 'sent'
);

CREATE TABLE IF NOT EXISTS message_receipts (
    receipt_id VARCHAR(64) PRIMARY KEY,
    message_id VARCHAR(64) REFERENCES messages(message_id) ON DELETE CASCADE,
    recipient_id VARCHAR(64) REFERENCES users(id),
    status VARCHAR(32) NOT NULL,
    timestamp BIGINT NOT NULL,
    signature TEXT
);

CREATE TABLE IF NOT EXISTS connections (
    id VARCHAR(64) PRIMARY KEY,
    requester_id VARCHAR(64) REFERENCES users(id),
    target_id VARCHAR(64) REFERENCES users(id),
    status VARCHAR(32) NOT NULL,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    UNIQUE(requester_id, target_id)
);

CREATE TABLE IF NOT EXISTS pending_messages (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(64) REFERENCES users(id),
    message_id VARCHAR(64) REFERENCES messages(message_id) ON DELETE CASCADE,
    created_at BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
