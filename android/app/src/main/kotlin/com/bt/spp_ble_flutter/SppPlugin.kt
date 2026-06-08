package com.bt.spp_ble_flutter

import android.bluetooth.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID

/** SPP (经典蓝牙串口) MethodChannel 插件 — 移植自 BluetoothChatService.java */
class SppPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    private val adapter: BluetoothAdapter? by lazy {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        manager?.adapter
    }

    companion object {
        private const val CHANNEL = "com.bt.spp_ble/spp"
        private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        // 状态常量 (与 Dart 端一致)
        private const val STATE_NONE = 0
        private const val STATE_CONNECTING = 1
        private const val STATE_CONNECTED = 2
    }

    // 连接相关
    private var connectThread: ConnectThread? = null
    private var connectedThread: ConnectedThread? = null
    private var currentState = STATE_NONE

    // 扫描相关
    private var isScanning = false
    private val foundDevices = mutableListOf<Map<String, Any?>>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        disconnect()
        stopScan()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan" -> startScan(result)
            "stopScan" -> stopScan(result)
            "connect" -> {
                val address = call.argument<String>("address")
                if (address != null) connect(address, result) else result.error("INVALID", "address required", null)
            }
            "disconnect" -> disconnect(result)
            "write" -> {
                val data = call.argument<ByteArray>("data")
                if (data != null) write(data, result) else result.error("INVALID", "data required", null)
            }
            "getState" -> result.success(currentState)
            else -> result.notImplemented()
        }
    }

    // ─── 扫描 ────────────────────────────────────────────────────────

    private val discoveryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                BluetoothDevice.ACTION_FOUND -> {
                    val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                    val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, 0.toShort())
                    if (device != null && device.name != null) {
                        val entry = mapOf(
                            "name" to (device.name ?: "未知"),
                            "address" to device.address,
                            "rssi" to rssi.toInt(),
                            "type" to "SPP"
                        )
                        // 去重
                        if (foundDevices.none { it["address"] == device.address }) {
                            foundDevices.add(entry)
                        }
                        channel.invokeMethod("onDeviceFound", entry)
                    }
                }
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    channel.invokeMethod("onScanFinished", null)
                    isScanning = false
                }
            }
        }
    }

    private fun startScan(result: MethodChannel.Result) {
        if (isScanning) {
            result.success(true)
            return
        }
        foundDevices.clear()
        isScanning = true

        // 先列出已配对设备
        adapter?.bondedDevices?.forEach { device ->
            if (device.name != null) {
                val entry = mapOf(
                    "name" to (device.name ?: "未知"),
                    "address" to device.address,
                    "rssi" to 0,
                    "type" to "SPP"
                )
                foundDevices.add(entry)
                channel.invokeMethod("onDeviceFound", entry)
            }
        }

        // 注册发现广播
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        context.registerReceiver(discoveryReceiver, filter)

        // 开始发现
        adapter?.cancelDiscovery()
        adapter?.startDiscovery()

        result.success(true)
    }

    private fun stopScan(result: MethodChannel.Result? = null) {
        try {
            context.unregisterReceiver(discoveryReceiver)
        } catch (_: Exception) {}
        adapter?.cancelDiscovery()
        isScanning = false
        result?.success(true)
    }

    // ─── 连接 ────────────────────────────────────────────────────────

    private fun connect(address: String, result: MethodChannel.Result) {
        val device = adapter?.getRemoteDevice(address)
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "找不到设备: $address", null)
            return
        }

        connectThread?.cancel()
        connectedThread?.cancel()

        currentState = STATE_CONNECTING
        sendStateChange()

        connectThread = ConnectThread(device).apply { start() }
        result.success(true)
    }

    private inner class ConnectThread(private val device: BluetoothDevice) : Thread() {
        private var socket: BluetoothSocket? = null
        private var cancelled = false

        override fun run() {
            try {
                socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                adapter?.cancelDiscovery()
                socket?.connect()

                if (!cancelled) {
                    connectedThread = ConnectedThread(socket!!).apply { start() }
                    currentState = STATE_CONNECTED
                    sendStateChange()
                    channel.invokeMethod("onConnected", mapOf(
                        "name" to (device.name ?: "未知"),
                        "address" to device.address
                    ))
                }
            } catch (e: IOException) {
                currentState = STATE_NONE
                sendStateChange()
                channel.invokeMethod("onError", "连接失败: ${e.message}")
            }
        }

        fun cancel() {
            cancelled = true
            try { socket?.close() } catch (_: Exception) {}
        }
    }

    private inner class ConnectedThread(private val socket: BluetoothSocket) : Thread() {
        private val inputStream: InputStream? = socket.inputStream
        private val outputStream: OutputStream? = socket.outputStream

        override fun run() {
            val buffer = ByteArray(1024)
            while (true) {
                try {
                    val bytes = inputStream?.read(buffer) ?: -1
                    if (bytes > 0) {
                        val data = buffer.copyOf(bytes)
                        channel.invokeMethod("onDataReceived", data)
                    }
                } catch (_: IOException) {
                    connectionLost()
                    break
                }
            }
        }

        fun write(data: ByteArray): Boolean {
            return try {
                outputStream?.write(data)
                outputStream?.flush()
                channel.invokeMethod("onDataSent", data.size)
                true
            } catch (_: IOException) {
                false
            }
        }

        fun cancel() {
            try { socket.close() } catch (_: Exception) {}
        }
    }

    private fun connectionLost() {
        currentState = STATE_NONE
        sendStateChange()
        channel.invokeMethod("onDisconnected", null)
    }

    private fun write(data: ByteArray, result: MethodChannel.Result) {
        val ct = connectedThread
        if (ct == null || currentState != STATE_CONNECTED) {
            result.error("NOT_CONNECTED", "未连接", null)
            return
        }
        val ok = ct.write(data)
        result.success(ok)
    }

    private fun disconnect(result: MethodChannel.Result? = null) {
        connectedThread?.cancel()
        connectedThread = null
        connectThread?.cancel()
        connectThread = null
        currentState = STATE_NONE
        sendStateChange()
        result?.success(true)
    }

    private fun sendStateChange() {
        channel.invokeMethod("onStateChange", currentState)
    }
}
