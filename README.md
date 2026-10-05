# QuickChat — 100% Offline Bluetooth Mesh Group Messenger

> **"Zero Internet. Zero Cellular Towers. Zero SIM Cards. 100% Decentralized Mesh Groups."**

QuickChat is an offline communication platform for Android that connects nearby smartphones into an autonomous **Multi-Hop Bluetooth Low Energy (BLE) Mesh Chain** (`Phone A ➔ Phone B ➔ Phone C ➔ Phone D ➔ ♾️`). All messages broadcast across persistent mesh groups with zero cellular data or Wi-Fi required.
 
📱 **Direct APK Download**: [QuickChat-Mesh-Offline.apk](https://github.com/Cyconik/QuickChat/raw/main/QuickChat-Mesh-Offline.apk)

---

## 🏗 Architecture & Multi-Hop Chain

```
[ Phone A ] -------- BLE --------> [ Phone B ] -------- BLE --------> [ Phone C ]
  (Sender)                        (Mesh Relay 1)                     (Mesh Relay 2)
                                                                            |
                                                                           BLE
                                                                            v
[ Group #Nearby-Public-Mesh ] <--- BLE <----------------------------- [ Phone D ]
(All Connected Devices)                                              (Mesh Relay 3)
```

- **Native BLE GATT Server & Client**: Custom Android Plugin (`NativeBleMeshPlugin.java`) operates continuous BLE advertising, background scanning, and bidirectional GATT notifications.
- **Packet Chunking & Reassembly**: Packets are segmented (`QC:seqId:idx:total:data`) and reassembled seamlessly to prevent any MTU truncation.
- **Deterministic Canonical Group IDs**: Group names map deterministically (`#Mountain-Trek` ➔ `group_mountain_trek`) guaranteeing synchronization across all phones in the network.
- **Gossip Topology Sync**: Heartbeat packets (`PEER_HEARTBEAT`) sync discovered groups and relay routes automatically.

---

## ✨ Features

- 📢 **#Nearby-Public-Mesh**: Instant broadcast channel for all connected phones in radio range.
- 👥 **Permanent Custom Mesh Groups**: Create permanent groups (e.g. `#Trek-Squad`, `#Campus-Hub`, `#Emergency-SOS`) that propagate across the mesh.
- 🔄 **Infinite Multi-Hop Relaying**: Intermediate phones act as zero-knowledge packet forwarders without a 4-node limit.
- 🔔 **Audible Chimes & Vibration Alerts**: Instant Web Audio chime and haptic feedback on every incoming group message.
- 👑 **Admin Controls**: Group creators receive an Admin crown badge 👑 and can clear chat history across all participating nodes.
- 🛡️ **100% Anonymous & Private**: No phone numbers, no emails, no account registration.

---

## 📱 Installation & Setup Guide (Important)

Follow these steps carefully after downloading the APK to ensure continuous background listening:

### 1️⃣ Step 1: Install APK & Close Recent Apps First
- Download and install [QuickChat-Mesh-Offline.apk](https://github.com/Cyconik/QuickChat/raw/main/QuickChat-Mesh-Offline.apk).
- Before opening the app for the first time, close all background apps and tabs from your phone's Recent Apps screen.

### 2️⃣ Step 2: Open App & Set Username
- Launch QuickChat.
- Enter your Display Name and Username handle (or tap **🎲 Shuffle** to pick a quick 1-tap nickname).
- Tap **Launch QuickChat Mesh 🚀**.

### 3️⃣ Step 3: Grant Permissions (Bluetooth & Location)
- Allow **Bluetooth / Nearby Devices** and **Location** permissions so the native BLE radio can scan and broadcast.
- *Troubleshooting*: If permission prompts do not appear, clear QuickChat from Recent Apps and reopen it, or go to **Phone Settings ➔ Apps ➔ QuickChat ➔ Permissions** and manually grant "Nearby Devices" and "Location".

### 4️⃣ Step 4: Lock App in Background (Crucial) 🔒
- To ensure you **never miss any incoming group messages**, keep QuickChat running in the background.
- Open your phone's **Recent Apps** menu, long-press / tap the 3 dots on the QuickChat card, and choose **Lock App (🔒)**.
- Set Battery Usage to **"Unrestricted / Don't Optimize"** so Android does not kill the background Bluetooth radio.

---

## 🛠 Tech Stack

- **Android Client**: Capacitor + Native Java BLE Plugin (`android.bluetooth.le`, GATT Server/Client)
- **Web Frontend**: Vanilla JavaScript, Responsive CSS, Web Audio API, Service Worker PWA
- **Local Storage**: IndexedDB / LocalStorage for offline chat persistence
- **WAN Bridge (Optional)**: MQTT WebSocket client (`broker.emqx.io`) for multi-device internet fallback when connectivity is available

---

## 📄 License

Open source under the [MIT License](LICENSE).
