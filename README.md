# QuickChat — Multi-Hop BLE Mesh Chat & Nearby Social Platform

> **"Chat nearby. Connect privately. Stay connected even when the internet doesn't."**

QuickChat is a decentralized mobile communication application built with **Flutter (Dart)** and a high-performance **Node.js / TypeScript / WebSocket / PostgreSQL** backend. It enables nearby user discovery, direct and group messaging, and multi-hop Bluetooth Low Energy (BLE) forwarding across participating devices without requiring cellular towers or active internet connections.

---

## 🏗 System Architecture

```
                                +---------------------------+
                                |  QuickChat Cloud Gateway  |
                                |  (Node.js / WS / Postgres)|
                                +-------------+-------------+
                                              ^
                            (Internet Fallback / Auto-Sync)
                                              v
[ Phone A ] -------- BLE --------> [ Phone B ] -------- BLE --------> [ Phone C ]
  (Sender)                        (Mesh Relay 1)                     (Mesh Relay 2)
                                                                            |
                                                                           BLE
                                                                            v
[ Phone E ] <--------------------- BLE <----------------------------- [ Phone D ]
(Destination)                     (Mesh Relay 4)                     (Mesh Relay 3)
```

### Core Architecture Layers:
- **Presentation**: Flutter Riverpod with Plus Jakarta Sans typography, deep navy background, electric cyan & neon mint accents, glassmorphic surfaces, and real-time status indicators.
- **Mesh Network Engine (`MeshNetworkEngine`)**:
  - Peer registration and heartbeat expiration.
  - Seen message cache deduplication (prevents loops like `A → B → C → B → A`).
  - Strict TTL decrement (8 → 7 → ... → 0) and hop counting.
  - Store-and-Forward local queuing when next-hop nodes are temporarily disconnected.
  - Cryptographic delivery acknowledgements (ACK envelopes).
- **Security & Cryptography (`CryptoEngine` & `E2EEncryptionService`)**:
  - Anonymous cryptographic identity generation (`usr_XXXXXX`) with Ed25519 / ECDH keypairs.
  - End-to-End authenticated encryption with AES-256-GCM.
  - Digital message signatures and replay protection.
  - Intermediate mesh relay nodes are zero-knowledge (cannot read or modify payload).
- **Hybrid Transport Router (`HybridRouter`)**:
  - Automatically selects: Direct BLE radio → Multi-hop Mesh → Cloud WebSocket fallback.
- **Backend (`server/`)**:
  - Express REST APIs + WebSocket server for real-time bidirectional message distribution, user presence, group fanout, and offline sync.

---

## 📁 Project Structure

```
quickchat/
├── mobile/                               # Flutter Mobile Client
│   ├── pubspec.yaml
│   ├── android/                          # Android Native Permissions & Manifest
│   ├── ios/                              # iOS CoreBluetooth Info.plist & Config
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── constants/app_constants.dart
│       │   ├── security/crypto_engine.dart
│       │   └── theme/
│       ├── data/
│       │   ├── local/local_storage_service.dart
│       │   └── models/
│       ├── services/
│       │   ├── ble/ble_mesh_service.dart
│       │   ├── mesh/mesh_network_engine.dart
│       │   ├── encryption/e2e_encryption_service.dart
│       │   ├── websocket/websocket_service.dart
│       │   ├── routing/hybrid_router.dart
│       │   └── simulator/mesh_simulator_engine.dart
│       └── features/
│           ├── auth/
│           ├── onboarding/
│           ├── home/
│           ├── chats/
│           ├── nearby/
│           ├── groups/
│           ├── profile/
│           ├── settings/
│           ├── simulator/
│           └── debug/
├── server/                               # Node.js + TypeScript Backend
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── index.ts
│       ├── controllers/
│       ├── database/
│       ├── middleware/
│       └── websocket/
├── mesh_web_visualizer/                  # Standalone Interactive 5-Node Visualizer
│   └── index.html
├── .env.example
└── README.md
```

---

## 🚀 Getting Started

### 1. Backend Server Setup

```bash
cd server
npm install
npm run build
npm start
```
- REST Server: `http://localhost:3000`
- WebSocket Server: `ws://localhost:3000/ws`
- Health Check: `http://localhost:3000/health`

### 2. Interactive Mesh Simulator Web Testbed
Open `mesh_web_visualizer/index.html` in any web browser to interactively test and visualize:
- 5-node linear multi-hop (`A → B → C → D → E`)
- Direct BLE messaging (`A → B`)
- Group broadcast fanout (`Delhi Tech Community`)
- Disconnecting Node C to watch Store-and-Forward buffering, then reconnecting Node C to trigger queue flushing and delivery.

### 3. Flutter Mobile App Setup

```bash
cd mobile
flutter pub get
flutter run
```

---

## 📱 Testing Scenarios

### Test 1: Testing on Two Phones (Direct BLE)
1. Install QuickChat on **Phone A** and **Phone B**.
2. Turn off Cellular Data and Wi-Fi on both phones (keep Bluetooth enabled).
3. Open QuickChat on both phones and complete anonymous identity creation.
4. On Phone A, go to the **Nearby** tab — Phone B will appear with approximate proximity.
5. Tap **Message** and send `"Hello from Phone A"`.
6. **Result**: Phone B receives and decrypts the message directly over Bluetooth Low Energy radio.

### Test 2: Testing on 5+ Phones (Multi-Hop Mesh: A → B → C → D → E)
1. Place 5 devices in a line such that:
   - Phone A can reach only Phone B.
   - Phone B can reach Phone A and Phone C.
   - Phone C can reach Phone B and Phone D.
   - Phone D can reach Phone C and Phone E.
   - Phone E is physically outside Phone A's direct Bluetooth range.
2. On Phone A, send a message to Phone E: `"Hello Node E across 4 hops!"`.
3. **Observation**:
   - Phone A originates packet with `TTL = 8`, `hopCount = 0`.
   - Phone B receives packet, validates signature, decrements `TTL = 7`, increments `hopCount = 1`, and relays.
   - Phone C relays (`TTL = 6`, `hopCount = 2`).
   - Phone D relays (`TTL = 5`, `hopCount = 3`).
   - Phone E recognizes destination identity, decrypts payload, and displays `✓✓✓ Delivered (4 hops)`.
   - Phone E generates an ACK envelope that propagates back to Phone A to update delivery ticks.

### Test 3: Disconnected Node & Store-and-Forward (A → B → [Broken C] → D → E)
1. Turn off Bluetooth on intermediate Phone C.
2. Phone A sends message to Phone E.
3. Phone B attempts forwarding, finds no route, and buffers the encrypted message in its local `qc_store_forward_queue`.
4. Turn on Bluetooth on Phone C.
5. Phone B's periodic flush timer detects Phone C, flushes the queue, and message delivery succeeds.

---

## 🔒 Security & Privacy Model

- **Zero-Knowledge Relays**: Relay nodes (`Phone B`, `Phone C`, `Phone D`) forward only encrypted ciphertext (`encryptedPayload`), digital signatures, and TTL headers. They possess no cryptographic keys to decrypt plaintext message content.
- **Replay & Loop Protection**: Every device stores seen `messageId` hashes in disk cache. Duplicate packets are dropped immediately before radio retransmission.
- **Privacy Controls**: Users can configure who can discover their handle (Everyone, Connections Only, Nobody) and toggle their participation in mesh forwarding at any time from Settings.

---

## ⚠️ Known Platform Limitations & Graceful Fallbacks

1. **iOS Background Advertising Restrictions**:
   - iOS CoreBluetooth allows background central scanning only with explicit 128-bit Service UUIDs.
   - Background peripheral advertising on iOS places service UUIDs in a proprietary overflow area and omits the local name. QuickChat handles this by using explicit GATT service UUID matching (`6E400001-B5A3-F393-E0A9-E50E24DCCA9E`) and state restoration (`CBCentralManagerOptionRestoreIdentifierKey`).
2. **Android Background Duty-Cycling**:
   - On Android 8.0+, background BLE operations are constrained by OS Doze mode. QuickChat provides an optional Android Foreground Service with low-power duty cycling.
3. **Range Realism**:
   - BLE range per hop is approximately 10–30 meters depending on physical obstructions. Multi-hop forwarding allows reaching distant devices across chains of intermediate phones.
