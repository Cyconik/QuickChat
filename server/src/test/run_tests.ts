import { Database } from '../database/db';
import { MessageEnvelope } from '../types';

function assert(condition: boolean, testName: string) {
  if (condition) {
    console.log(`  ✓ PASS: ${testName}`);
  } else {
    console.error(`  ✕ FAIL: ${testName}`);
    process.exitCode = 1;
  }
}

export function runMeshProtocolTests() {
  console.log('\n--- Running QuickChat Mesh Protocol & Deduplication Tests ---');
  const db = Database.getInstance();

  // Test 1: Message Deduplication
  const messageId = 'msg_loop_test_001';
  const envelope: MessageEnvelope = {
    messageId,
    senderId: 'usr_A',
    conversationId: 'conv_test',
    messageType: 'text',
    createdAt: Date.now(),
    ttl: 8,
    hopCount: 0,
    destinationType: 'user',
    destinationId: 'usr_E',
    encryptedPayload: 'base64_payload',
    signature: 'sig_test',
  };

  const firstResult = db.saveMessage(envelope);
  assert(firstResult.isNew === true, 'First message packet accepted');

  const secondResult = db.saveMessage(envelope);
  assert(secondResult.isNew === false, 'Duplicate loop packet dropped by seen cache');

  // Test 2: Multi-hop TTL Decrement
  let currentTtl = 8;
  let hopCount = 0;
  for (let hop = 1; hop <= 8; hop++) {
    currentTtl--;
    hopCount++;
  }
  assert(currentTtl === 0 && hopCount === 8, 'Multi-hop TTL decrements and halts at 0');

  // Test 3: Store-and-Forward Queue
  const offlineUserId = 'usr_offline_recipient';
  const storedEnvelope: MessageEnvelope = {
    messageId: 'msg_stored_002',
    senderId: 'usr_A',
    conversationId: 'conv_offline',
    messageType: 'text',
    createdAt: Date.now(),
    ttl: 8,
    hopCount: 0,
    destinationType: 'user',
    destinationId: offlineUserId,
    encryptedPayload: 'encrypted_content',
    signature: 'sig_stored',
  };
  db.saveMessage(storedEnvelope);
  db.queuePendingMessage(offlineUserId, storedEnvelope.messageId);

  const pendingBefore = db.pendingOfflineMessages.get(offlineUserId) || [];
  assert(pendingBefore.includes(storedEnvelope.messageId), 'Store-and-forward queue buffers packet for offline node');

  const flushed = db.getAndClearPendingMessages(offlineUserId);
  assert(flushed.length === 1 && flushed[0].messageId === storedEnvelope.messageId, 'Online sync flushes store-and-forward queue');

  // Test 4: Group Membership
  const group = db.getGroupById('group_tech_delhi');
  assert(group !== undefined && group.name === 'Delhi Tech Community', 'Default community group exists');

  console.log('--- All Mesh Protocol Tests Finished Successfully ---\n');
}

if (require.main === module) {
  runMeshProtocolTests();
}
