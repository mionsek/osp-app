package pl.osp.osp_app

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Wyszukiwanie i parowanie drukarek Bluetooth z poziomu aplikacji.
 *
 * Wtyczka do druku (`print_bluetooth_thermal`) widzi wyłącznie urządzenia
 * już sparowane w ustawieniach telefonu, więc samo parowanie robimy tutaj:
 * klasyczne wyszukiwanie (drukarki NETUM nie są urządzeniami BLE) i prośba
 * o sparowanie, którą system obsługuje własnym oknem — także z PIN-em.
 */
class MainActivity : FlutterActivity() {
    private var events: EventChannel.EventSink? = null
    private var receiverRegistered = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                BluetoothDevice.ACTION_FOUND ->
                    intent.device()?.let { events?.success(deviceEvent("found", it)) }
                BluetoothDevice.ACTION_BOND_STATE_CHANGED ->
                    intent.device()?.let { events?.success(deviceEvent("bond", it)) }
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED ->
                    events?.success(mapOf("type" to "finished"))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "pl.osp.osp_app/bt_pairing/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    events = sink
                    registerBluetoothReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                    cancelDiscovery()
                    unregisterBluetoothReceiver()
                }
            },
        )

        MethodChannel(messenger, "pl.osp.osp_app/bt_pairing").setMethodCallHandler { call, result ->
            when (call.method) {
                "startDiscovery" -> result.success(startDiscovery())
                "stopDiscovery" -> {
                    cancelDiscovery()
                    result.success(null)
                }
                "bond" -> result.success(bond(call.argument<String>("mac") ?: ""))
                "openBluetoothSettings" -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Druk Bluetooth: strony PDF w szarości, w pasach — patrz
        // PdfBandRasterizer. Renderowanie trwa kilka sekund, więc idzie na
        // osobnym wątku, a odpowiedź wraca na wątek główny.
        MethodChannel(messenger, "pl.osp.osp_app/pdf_raster").setMethodCallHandler { call, result ->
            val pdf = call.argument<ByteArray>("pdf")
            if (pdf == null) {
                result.error("args", "Brak dokumentu PDF", null)
                return@setMethodCallHandler
            }
            rasterExecutor.execute {
                val reply: () -> Unit = try {
                    when (call.method) {
                        "pageCount" -> {
                            val count = withTempPdf(pdf) { PdfBandRasterizer.pageCount(it) }
                            ({ result.success(count) })
                        }
                        "renderPage" -> {
                            val page = withTempPdf(pdf) {
                                PdfBandRasterizer.renderPage(
                                    it,
                                    call.argument<Int>("page") ?: 0,
                                    call.argument<Double>("dpi") ?: 200.0,
                                    call.argument<Int>("supersample") ?: 1,
                                    call.argument<Int>("bandRows") ?: 64,
                                )
                            }
                            ({
                                result.success(
                                    mapOf("width" to page.width, "height" to page.height, "gray" to page.gray),
                                )
                            })
                        }
                        else -> ({ result.notImplemented() })
                    }
                } catch (e: Throwable) {
                    // Także OutOfMemoryError — komunikat zamiast zamknięcia aplikacji.
                    val message = "${e.javaClass.simpleName}: ${e.message}"
                    ({ result.error("raster", message, null) })
                }
                mainHandler.post(reply)
            }
        }
    }

    private val rasterExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private fun <T> withTempPdf(pdf: ByteArray, block: (File) -> T): T {
        val file = File.createTempFile("bt_print", ".pdf", cacheDir)
        try {
            file.writeBytes(pdf)
            return block(file)
        } finally {
            file.delete()
        }
    }

    override fun onDestroy() {
        // Rozpoczęte renderowanie się dokończy, nowe nie ruszy.
        rasterExecutor.shutdown()
        cancelDiscovery()
        unregisterBluetoothReceiver()
        super.onDestroy()
    }

    private val adapter: BluetoothAdapter?
        get() = (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private fun granted(permission: String) =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    /**
     * Zwraca stan zamiast wyjątku, żeby po stronie Darta dało się pokazać
     * konkretny komunikat: brak Bluetooth, wyłączony, brak zgody.
     */
    @SuppressLint("MissingPermission")
    private fun startDiscovery(): String {
        val bt = adapter ?: return "unavailable"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!granted(Manifest.permission.BLUETOOTH_SCAN) ||
                !granted(Manifest.permission.BLUETOOTH_CONNECT)
            ) return "no_permission"
        } else if (!granted(Manifest.permission.ACCESS_FINE_LOCATION)) {
            // Do Androida 11 wyszukiwanie urządzeń wymaga zgody na lokalizację.
            return "needs_location"
        }
        if (!bt.isEnabled) return "off"
        registerBluetoothReceiver()
        if (bt.isDiscovering) bt.cancelDiscovery()
        return if (bt.startDiscovery()) "ok" else "failed"
    }

    @SuppressLint("MissingPermission")
    private fun cancelDiscovery() {
        try {
            adapter?.takeIf { it.isDiscovering }?.cancelDiscovery()
        } catch (_: SecurityException) {
        }
    }

    /**
     * `bonded` — urządzenie już jest sparowane (system nie wyśle wtedy
     * żadnego zdarzenia), `started` — system pokazuje okno parowania,
     * `failed` — nie udało się zacząć.
     */
    @SuppressLint("MissingPermission")
    private fun bond(mac: String): String {
        val bt = adapter ?: return "failed"
        if (!BluetoothAdapter.checkBluetoothAddress(mac)) return "failed"
        return try {
            // Wyszukiwanie spowalnia i potrafi zerwać parowanie.
            if (bt.isDiscovering) bt.cancelDiscovery()
            val device = bt.getRemoteDevice(mac)
            when {
                device.bondState == BluetoothDevice.BOND_BONDED -> "bonded"
                device.createBond() -> "started"
                else -> "failed"
            }
        } catch (_: SecurityException) {
            "failed"
        }
    }

    @SuppressLint("MissingPermission")
    private fun deviceEvent(type: String, device: BluetoothDevice): Map<String, Any> {
        val name = try {
            device.name ?: ""
        } catch (_: SecurityException) {
            ""
        }
        val bondState = try {
            device.bondState
        } catch (_: SecurityException) {
            BluetoothDevice.BOND_NONE
        }
        val major = try {
            device.bluetoothClass?.majorDeviceClass ?: 0
        } catch (_: SecurityException) {
            0
        }
        return mapOf(
            "type" to type,
            "name" to name,
            "mac" to device.address,
            "bondState" to when (bondState) {
                BluetoothDevice.BOND_BONDED -> "bonded"
                BluetoothDevice.BOND_BONDING -> "bonding"
                else -> "none"
            },
            "printerClass" to (major == BluetoothClass.Device.Major.IMAGING),
        )
    }

    private fun registerBluetoothReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterBluetoothReceiver() {
        if (!receiverRegistered) return
        try {
            unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
        }
        receiverRegistered = false
    }

    @Suppress("DEPRECATION")
    private fun Intent.device(): BluetoothDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }
}
