package app.livenavigator

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.GeolocationPermissions
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.webkit.WebViewAssetLoader
import java.util.UUID

class MainActivity : ComponentActivity() {
    private lateinit var webView: WebView
    private var pendingGeoOrigin: String? = null
    private var pendingGeoCallback: GeolocationPermissions.Callback? = null
    private var pendingBleAction: (() -> Unit)? = null
    private var pendingBlePermissions: Array<String> = emptyArray()
    private val bleHandler = Handler(Looper.getMainLooper())
    private var scannerCallback: ScanCallback? = null
    private var advertiserCallback: AdvertiseCallback? = null
    private var sharingLineCode = 0
    private val sightings = mutableMapOf<String, Long>()
    private val serviceUuid = UUID.fromString("e74b8e4c-0f30-4b2c-ae31-fcfb1e6c9001")
    private val serviceParcel by lazy { android.os.ParcelUuid(serviceUuid) }

    private val locationPermission = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { grants ->
        val granted = grants[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            grants[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        pendingGeoCallback?.invoke(pendingGeoOrigin, granted, false)
        pendingGeoCallback = null
        pendingGeoOrigin = null
    }

    private val bluetoothPermission = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { grants ->
        val granted = pendingBlePermissions.all { permission ->
            grants[permission] == true || ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        }
        pendingBlePermissions = emptyArray()
        val action = pendingBleAction
        pendingBleAction = null
        if (granted) action?.invoke() else emitBle("Nearby-device permission was not granted.")
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.WHITE
        window.navigationBarColor = Color.WHITE
        window.decorView.systemUiVisibility =
            android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or
                android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR

        val assetLoader = WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()

        webView = WebView(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.WHITE)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.geolocationEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.setSupportZoom(false)
            addJavascriptInterface(BleBridge(), "MetroBle")
            webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(
                    view: WebView?, request: WebResourceRequest?
                ) = request?.url?.let(assetLoader::shouldInterceptRequest)
            }
            webChromeClient = object : WebChromeClient() {
                override fun onGeolocationPermissionsShowPrompt(
                    origin: String?, callback: GeolocationPermissions.Callback?
                ) {
                    val fine = ContextCompat.checkSelfPermission(
                        this@MainActivity, Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    val coarse = ContextCompat.checkSelfPermission(
                        this@MainActivity, Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    if (fine || coarse) {
                        callback?.invoke(origin, true, false)
                    } else {
                        pendingGeoOrigin = origin
                        pendingGeoCallback = callback
                        locationPermission.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            )
                        )
                    }
                }
            }
        }
        setContentView(webView)
        webView.loadUrl("https://appassets.androidplatform.net/assets/www/index.html")
    }

    private fun requiredBlePermissions(advertise: Boolean): Array<String> = if (Build.VERSION.SDK_INT >= 31) {
        arrayOf(if (advertise) Manifest.permission.BLUETOOTH_ADVERTISE else Manifest.permission.BLUETOOTH_SCAN)
    } else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)

    private fun withBlePermission(advertise: Boolean, action: () -> Unit) {
        val permissions = requiredBlePermissions(advertise)
        val missing = permissions.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) action() else {
            pendingBleAction = action
            pendingBlePermissions = permissions
            bluetoothPermission.launch(missing.toTypedArray())
        }
    }

    private fun adapter(): BluetoothAdapter? = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter

    private fun emitBle(message: String, lineCode: Int? = null, count: Int? = null) {
        val detail = if (lineCode == null) "{type:'status',message:${org.json.JSONObject.quote(message)}}"
            else "{type:'count',lineCode:$lineCode,count:${count ?: 0}}"
        runOnUiThread {
            if (::webView.isInitialized) webView.evaluateJavascript(
                "window.dispatchEvent(new CustomEvent('metro-ble',{detail:$detail}));", null
            )
        }
    }

    private inner class BleBridge {
        @JavascriptInterface fun startCongestionScan() = withBlePermission(false) { startScan() }
        @JavascriptInterface fun stopCongestionScan() = runOnUiThread { stopScan(); emitBle("Congestion scan stopped.") }
        @JavascriptInterface fun startRiderSharing(lineCode: Int) = withBlePermission(true) { startSharing(lineCode) }
        @JavascriptInterface fun stopRiderSharing() = runOnUiThread { stopSharing(); emitBle("Anonymous sharing stopped.") }
    }

    @SuppressLint("MissingPermission")
    private fun startScan() {
        val scanner = adapter()?.bluetoothLeScanner
        if (scanner == null) { emitBle("Bluetooth is off or BLE scanning is unavailable."); return }
        stopScan()
        synchronized(sightings) { sightings.clear() }
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val payload = result.scanRecord?.getServiceData(serviceParcel) ?: return
                if (payload.size < 6 || payload[0].toInt() != 1) return
                val line = payload[1].toInt() and 0xff
                if (line !in 1..10) return
                val token = payload.sliceArray(2..5).joinToString("") { "%02x".format(it) }
                synchronized(sightings) { sightings["$line:$token"] = System.currentTimeMillis() }
            }
            override fun onScanFailed(errorCode: Int) { emitBle("BLE scan failed (error $errorCode).") }
        }
        scannerCallback = callback
        scanner.startScan(
            listOf(ScanFilter.Builder().setServiceData(serviceParcel, byteArrayOf(1), byteArrayOf(0xff.toByte())).build()),
            ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), callback
        )
        emitBle("Scanning for nearby opt-in Live Navigator riders.")
        bleHandler.removeCallbacks(countRunnable)
        bleHandler.post(countRunnable)
    }

    private val countRunnable = object : Runnable {
        override fun run() {
            val cutoff = System.currentTimeMillis() - 60_000L
            synchronized(sightings) {
                sightings.entries.removeAll { it.value < cutoff }
                for (line in 1..10) emitBle("", line, sightings.keys.count { it.startsWith("$line:") })
            }
            if (scannerCallback != null) bleHandler.postDelayed(this, 5_000L)
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopScan() {
        scannerCallback?.let { callback -> runCatching { adapter()?.bluetoothLeScanner?.stopScan(callback) } }
        scannerCallback = null
        bleHandler.removeCallbacks(countRunnable)
    }

    @SuppressLint("MissingPermission")
    private fun startSharing(lineCode: Int) {
        if (lineCode !in 1..10) { emitBle("Choose a Metro line before sharing."); return }
        val advertiser = adapter()?.bluetoothLeAdvertiser
        if (advertiser == null) { emitBle("This device cannot broadcast BLE beacons."); return }
        stopSharing()
        sharingLineCode = lineCode
        beginAdvertisement(advertiser)
        emitBle("Sharing a rotating anonymous beacon for the selected line while this app stays open.")
    }

    @SuppressLint("MissingPermission")
    private fun beginAdvertisement(advertiser: android.bluetooth.le.BluetoothLeAdvertiser) {
        val token = ByteArray(4).also(java.security.SecureRandom()::nextBytes)
        val payload = byteArrayOf(1, sharingLineCode.toByte()) + token
        val data = AdvertiseData.Builder().addServiceData(serviceParcel, payload).setIncludeDeviceName(false).build()
        val settings = AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_LOW).setConnectable(false).build()
        val callback = object : AdvertiseCallback() {
            override fun onStartFailure(errorCode: Int) { emitBle("Could not start BLE sharing (error $errorCode).") }
        }
        advertiserCallback = callback
        advertiser.startAdvertising(settings, data, callback)
        bleHandler.postDelayed(rotateRunnable, 90_000L)
    }

    private val rotateRunnable = object : Runnable {
        @SuppressLint("MissingPermission")
        override fun run() {
            val advertiser = adapter()?.bluetoothLeAdvertiser ?: return
            advertiserCallback?.let { advertiser.stopAdvertising(it) }
            advertiserCallback = null
            if (sharingLineCode != 0) beginAdvertisement(advertiser)
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopSharing() {
        bleHandler.removeCallbacks(rotateRunnable)
        advertiserCallback?.let { callback -> runCatching { adapter()?.bluetoothLeAdvertiser?.stopAdvertising(callback) } }
        advertiserCallback = null
        sharingLineCode = 0
    }

    override fun onPause() {
        stopScan()
        stopSharing()
        super.onPause()
    }

    @Deprecated("Deprecated in Android API")
    override fun onBackPressed() {
        if (::webView.isInitialized && webView.canGoBack()) webView.goBack()
        else super.onBackPressed()
    }
}
