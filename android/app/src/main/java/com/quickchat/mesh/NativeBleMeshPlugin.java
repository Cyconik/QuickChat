package com.quickchat.mesh;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.BluetoothGattServerCallback;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.AdvertiseCallback;
import android.bluetooth.le.AdvertiseData;
import android.bluetooth.le.AdvertiseSettings;
import android.bluetooth.le.BluetoothLeAdvertiser;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;
import android.util.Log;

import androidx.core.app.ActivityCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@CapacitorPlugin(
    name = "NativeBleMesh",
    permissions = {
        @Permission(
            alias = "bluetooth",
            strings = {
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            }
        )
    }
)
public class NativeBleMeshPlugin extends Plugin {
    private static final String TAG = "QuickChatBleMesh";

    public static final UUID SERVICE_UUID = UUID.fromString("0000FE60-0000-1000-8000-00805F9B34FB");
    public static final UUID RX_CHAR_UUID = UUID.fromString("0000FE61-0000-1000-8000-00805F9B34FB"); // Write
    public static final UUID TX_CHAR_UUID = UUID.fromString("0000FE62-0000-1000-8000-00805F9B34FB"); // Notify
    public static final UUID CCCD_UUID    = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB");

    private BluetoothAdapter bluetoothAdapter;
    private BluetoothLeAdvertiser advertiser;
    private BluetoothLeScanner scanner;
    private BluetoothGattServer gattServer;

    private boolean isAdvertising = false;
    private boolean isScanning = false;
    private String selfUserId = "node_" + System.currentTimeMillis();
    private String selfDisplayName = "Nearby Phone";

    private final Map<String, BluetoothDevice> discoveredDevices = new ConcurrentHashMap<>();
    private final Map<String, BluetoothGatt> connectedGattClients = new ConcurrentHashMap<>();
    private final Map<String, BluetoothDevice> connectedGattServers = new ConcurrentHashMap<>();

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    @Override
    public void load() {
        super.load();
        BluetoothManager bluetoothManager = (BluetoothManager) getContext().getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetoothManager != null) {
            bluetoothAdapter = bluetoothManager.getAdapter();
        }
    }

    @PluginMethod
    public void startMeshRadio(PluginCall call) {
        selfUserId = call.getString("userId", selfUserId);
        selfDisplayName = call.getString("displayName", selfDisplayName);

        if (getPermissionState("bluetooth") != PermissionState.GRANTED) {
            requestPermissionForAlias("bluetooth", call, "bluetoothPermsCallback");
            return;
        }

        enableBluetoothAndStart(call);
    }

    @PermissionCallback
    private void bluetoothPermsCallback(PluginCall call) {
        if (getPermissionState("bluetooth") == PermissionState.GRANTED) {
            enableBluetoothAndStart(call);
        } else {
            call.reject("Bluetooth & Nearby permissions are required for offline mesh messaging.");
        }
    }

    private void enableBluetoothAndStart(PluginCall call) {
        BluetoothManager bluetoothManager = (BluetoothManager) getContext().getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetoothManager != null) {
            bluetoothAdapter = bluetoothManager.getAdapter();
        }

        if (bluetoothAdapter == null) {
            call.reject("Device does not support Bluetooth LE.");
            return;
        }

        if (!bluetoothAdapter.isEnabled()) {
            try {
                Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
                enableBtIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(enableBtIntent);
            } catch (Exception ignored) {}
        }

        try {
            if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                bluetoothAdapter.setName("QC_" + selfDisplayName.replace(" ", "_"));
            }
        } catch (Exception ignored) {}

        startGattServer();
        startAdvertising();
        startScanning();

        JSObject ret = new JSObject();
        ret.put("status", "ACTIVE");
        ret.put("serviceUuid", SERVICE_UUID.toString());
        call.resolve(ret);
    }

    @PluginMethod
    public void stopMeshRadio(PluginCall call) {
        stopAdvertising();
        stopScanning();
        stopGattServer();

        JSObject ret = new JSObject();
        ret.put("status", "STOPPED");
        call.resolve(ret);
    }

    @PluginMethod
    public void broadcastBlePacket(PluginCall call) {
        String jsonPayload = call.getString("packetJson");
        if (jsonPayload == null || jsonPayload.isEmpty()) {
            call.reject("Empty packetJson");
            return;
        }

        int sentCount = 0;
        byte[] payloadBytes = jsonPayload.getBytes(StandardCharsets.UTF_8);

        // 1. Send to all peers where we are the GATT Client (Write to RX)
        for (Map.Entry<String, BluetoothGatt> entry : connectedGattClients.entrySet()) {
            BluetoothGatt gatt = entry.getValue();
            try {
                BluetoothGattService service = gatt.getService(SERVICE_UUID);
                if (service != null) {
                    BluetoothGattCharacteristic rxChar = service.getCharacteristic(RX_CHAR_UUID);
                    if (rxChar != null) {
                        rxChar.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
                        rxChar.setValue(payloadBytes);
                        if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                            boolean ok = gatt.writeCharacteristic(rxChar);
                            if (ok) sentCount++;
                        }
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "Write characteristic error: " + entry.getKey(), e);
            }
        }

        // 2. Send to all peers connected to our GATT Server (Notify TX)
        if (gattServer != null) {
            try {
                BluetoothGattService serverService = gattServer.getService(SERVICE_UUID);
                if (serverService != null) {
                    BluetoothGattCharacteristic txChar = serverService.getCharacteristic(TX_CHAR_UUID);
                    if (txChar != null) {
                        txChar.setValue(payloadBytes);
                        for (Map.Entry<String, BluetoothDevice> serverEntry : connectedGattServers.entrySet()) {
                            if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                                gattServer.notifyCharacteristicChanged(serverEntry.getValue(), txChar, false);
                                sentCount++;
                            }
                        }
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "Notify characteristic error: ", e);
            }
        }

        JSObject ret = new JSObject();
        ret.put("transmittedNodes", sentCount);
        call.resolve(ret);
    }

    @PluginMethod
    public void getDiscoveredPeers(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("count", discoveredDevices.size());
        call.resolve(ret);
    }

    private void startGattServer() {
        if (gattServer != null) return;
        BluetoothManager bluetoothManager = (BluetoothManager) getContext().getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetoothManager == null) return;

        if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return;
        }

        gattServer = bluetoothManager.openGattServer(getContext(), new BluetoothGattServerCallback() {
            @Override
            public void onConnectionStateChange(BluetoothDevice device, int status, int newState) {
                super.onConnectionStateChange(device, status, newState);
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connectedGattServers.put(device.getAddress(), device);
                    Log.i(TAG, "GATT Client connected to our server: " + device.getAddress());
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    connectedGattServers.remove(device.getAddress());
                    Log.i(TAG, "GATT Client disconnected: " + device.getAddress());
                }
            }

            @Override
            public void onCharacteristicWriteRequest(BluetoothDevice device, int requestId, BluetoothGattCharacteristic characteristic, boolean preparedWrite, boolean responseNeeded, int offset, byte[] value) {
                super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value);
                
                if (responseNeeded && (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S)) {
                    gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value);
                }

                if (value != null && value.length > 0) {
                    String rawStr = new String(value, StandardCharsets.UTF_8);
                    mainHandler.post(() -> {
                        JSObject eventData = new JSObject();
                        eventData.put("rawPacket", rawStr);
                        eventData.put("senderHardwareId", device.getAddress());
                        notifyListeners("onPacketReceived", eventData);
                    });
                }
            }
        });

        BluetoothGattService service = new BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY);
        BluetoothGattCharacteristic rxChar = new BluetoothGattCharacteristic(
            RX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE | BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        );
        BluetoothGattCharacteristic txChar = new BluetoothGattCharacteristic(
            TX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ | BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        );
        BluetoothGattDescriptor cccd = new BluetoothGattDescriptor(CCCD_UUID, BluetoothGattDescriptor.PERMISSION_WRITE | BluetoothGattDescriptor.PERMISSION_READ);
        txChar.addDescriptor(cccd);

        service.addCharacteristic(rxChar);
        service.addCharacteristic(txChar);
        gattServer.addService(service);
        Log.i(TAG, "GATT Server running with Full Duplex Service: " + SERVICE_UUID);
    }

    private void stopGattServer() {
        if (gattServer != null) {
            if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                gattServer.close();
            }
            gattServer = null;
        }
    }

    private void startAdvertising() {
        if (isAdvertising || bluetoothAdapter == null) return;
        advertiser = bluetoothAdapter.getBluetoothLeAdvertiser();
        if (advertiser == null) return;

        if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_ADVERTISE) != PackageManager.PERMISSION_GRANTED && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return;
        }

        AdvertiseSettings settings = new AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0)
            .build();

        AdvertiseData data = new AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(new ParcelUuid(SERVICE_UUID))
            .build();

        advertiser.startAdvertising(settings, data, advertiseCallback);
        isAdvertising = true;
        Log.i(TAG, "BLE Advertising started");
    }

    private void stopAdvertising() {
        if (advertiser != null && isAdvertising) {
            if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                advertiser.stopAdvertising(advertiseCallback);
            }
            isAdvertising = false;
        }
    }

    private final AdvertiseCallback advertiseCallback = new AdvertiseCallback() {
        @Override
        public void onStartSuccess(AdvertiseSettings settingsInEffect) {
            super.onStartSuccess(settingsInEffect);
            Log.i(TAG, "BLE Advertise success");
        }

        @Override
        public void onStartFailure(int errorCode) {
            super.onStartFailure(errorCode);
            Log.e(TAG, "BLE Advertise failed with code: " + errorCode);
        }
    };

    private void startScanning() {
        if (isScanning || bluetoothAdapter == null) return;
        scanner = bluetoothAdapter.getBluetoothLeScanner();
        if (scanner == null) return;

        if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return;
        }

        List<ScanFilter> filters = new ArrayList<>();

        ScanSettings settings = new ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build();

        scanner.startScan(filters, settings, scanCallback);
        isScanning = true;
        Log.i(TAG, "BLE Scanning active");
    }

    private void stopScanning() {
        if (scanner != null && isScanning) {
            if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                scanner.stopScan(scanCallback);
            }
            isScanning = false;
        }
    }

    private final ScanCallback scanCallback = new ScanCallback() {
        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            super.onScanResult(callbackType, result);
            BluetoothDevice device = result.getDevice();
            if (device == null) return;

            ScanRecord record = result.getScanRecord();
            boolean isQuickChatPeer = false;

            if (record != null) {
                List<ParcelUuid> uuids = record.getServiceUuids();
                if (uuids != null && uuids.contains(new ParcelUuid(SERVICE_UUID))) {
                    isQuickChatPeer = true;
                }
                String deviceName = record.getDeviceName();
                if (deviceName != null && (deviceName.startsWith("QC_") || deviceName.contains("QuickChat"))) {
                    isQuickChatPeer = true;
                }
            }

            if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                String name = device.getName();
                if (name != null && (name.startsWith("QC_") || name.contains("QuickChat"))) {
                    isQuickChatPeer = true;
                }
            }

            if (!isQuickChatPeer) return;

            String addr = device.getAddress();
            if (!discoveredDevices.containsKey(addr)) {
                discoveredDevices.put(addr, device);
                Log.i(TAG, "Discovered Node over BLE: " + addr + " (RSSI: " + result.getRssi() + ")");

                String displayName = "Nearby Phone (" + addr.substring(Math.max(0, addr.length() - 5)) + ")";
                if (record != null && record.getDeviceName() != null) {
                    displayName = record.getDeviceName().replace("QC_", "");
                }

                final String peerDisplayName = displayName;
                mainHandler.post(() -> {
                    JSObject peerData = new JSObject();
                    peerData.put("hardwareId", addr);
                    peerData.put("name", peerDisplayName);
                    peerData.put("rssi", result.getRssi());
                    notifyListeners("onPeerDiscovered", peerData);
                });

                // Auto-connect GATT client
                connectGattClient(device);
            }
        }
    };

    private void connectGattClient(BluetoothDevice device) {
        if (connectedGattClients.containsKey(device.getAddress())) return;
        if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return;
        }

        device.connectGatt(getContext(), false, new BluetoothGattCallback() {
            @Override
            public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
                super.onConnectionStateChange(gatt, status, newState);
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connectedGattClients.put(device.getAddress(), gatt);
                    Log.i(TAG, "Connected to Peer GATT: " + device.getAddress());
                    if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        gatt.requestMtu(512);
                    }
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    connectedGattClients.remove(device.getAddress());
                    gatt.close();
                    Log.i(TAG, "Disconnected from Peer GATT: " + device.getAddress());
                }
            }

            @Override
            public void onMtuChanged(BluetoothGatt gatt, int mtu, int status) {
                super.onMtuChanged(gatt, mtu, status);
                Log.i(TAG, "MTU changed to " + mtu + " for " + gatt.getDevice().getAddress());
                if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                    gatt.discoverServices();
                }
            }

            @Override
            public void onServicesDiscovered(BluetoothGatt gatt, int status) {
                super.onServicesDiscovered(gatt, status);
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.i(TAG, "Discovered services on peer: " + gatt.getDevice().getAddress());
                    if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        BluetoothGattService service = gatt.getService(SERVICE_UUID);
                        if (service != null) {
                            BluetoothGattCharacteristic txChar = service.getCharacteristic(TX_CHAR_UUID);
                            if (txChar != null) {
                                gatt.setCharacteristicNotification(txChar, true);
                                BluetoothGattDescriptor desc = txChar.getDescriptor(CCCD_UUID);
                                if (desc != null) {
                                    desc.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                                    gatt.writeDescriptor(desc);
                                }
                            }
                        }
                    }
                }
            }

            @Override
            public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
                super.onCharacteristicChanged(gatt, characteristic);
                byte[] value = characteristic.getValue();
                if (value != null && value.length > 0) {
                    String rawStr = new String(value, StandardCharsets.UTF_8);
                    mainHandler.post(() -> {
                        JSObject eventData = new JSObject();
                        eventData.put("rawPacket", rawStr);
                        eventData.put("senderHardwareId", gatt.getDevice().getAddress());
                        notifyListeners("onPacketReceived", eventData);
                    });
                }
            }
        });
    }
}
