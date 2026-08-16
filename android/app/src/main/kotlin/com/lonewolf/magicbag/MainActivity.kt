package com.lonewolf.magicbag

import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.PictureInPictureParams
import android.util.Rational
import android.os.Build
import android.content.Context
import android.media.AudioManager
import android.app.RemoteAction
import android.graphics.drawable.Icon
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.content.res.Configuration
import android.app.PendingIntent
import android.view.KeyEvent
import android.os.Bundle
import android.os.SystemClock
import android.media.AudioFocusRequest
import android.media.AudioAttributes
import android.os.Handler
import android.os.Looper


class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.lonewolf.magicbag/shortcuts"

    // Variable para rastrear la conexión
    private var isMaletaConnected = false
    private var isRecording = false
    private var wasMusicPlayingBefore = false

    private var methodChannel: MethodChannel? = null
    // Declaración de la variable para Android 8.0+
    private var currentFocusRequest: AudioFocusRequest? = null

    private val voiceTimeoutHandler = Handler(Looper.getMainLooper())
    private val TIMEOUT_VOICE_MS = 7000L // 7 segundos

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter nos avisará cuando se conecte o desconecte
                "updateConnectionStatus" -> {
                    isMaletaConnected = call.arguments as Boolean
                    result.success(true)
                }
                "enterPipMode" -> {
                    enterPipMode()
                    result.success(true)
                }
                "startBluetoothMic" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    // VERIFICACIÓN CLAVE: ¿Hay música sonando ahora mismo?
                    wasMusicPlayingBefore = audioManager.isMusicActive
                    // 1. Pedimos foco de audio con Ducking ANTES de prender el micro
                    val currentFocusRequest = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                            .setAudioAttributes(AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ASSISTANT)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                .build())
                            .build()
                        audioManager.requestAudioFocus(focusRequest)
                    } else {
                        @Suppress("DEPRECATION")
                        audioManager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    }

                    // 2. CAMBIO CLAVE: Usamos MODE_IN_COMMUNICATION
                    // Esto le dice al sistema que mantenga el canal de medios abierto si es posible
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    
                    // 3. Activamos el Micro del Casco
                    audioManager.startBluetoothSco()
                    audioManager.isBluetoothScoOn = true
                    isRecording = true
                    result.success(true)
                }
                "stopBluetoothMic" -> {

                    // DETENER el timer inmediatamente
                    voiceTimeoutHandler.removeCallbacksAndMessages(null)

                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    // Cerramos el túnel de voz inmediatamente
                    audioManager.stopBluetoothSco()
                    audioManager.isBluetoothScoOn = false
                    audioManager.mode = AudioManager.MODE_NORMAL
                    // Devolvemos el foco de audio
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        currentFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
                    } else {
                        audioManager.abandonAudioFocus(null)
                    }
                    if(wasMusicPlayingBefore){
                    // "Empujoncito" a Media para que retome
                        Handler(Looper.getMainLooper()).postDelayed({
                            val eventTime = SystemClock.uptimeMillis()
                            audioManager.dispatchMediaKeyEvent(KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY, 0))
                            audioManager.dispatchMediaKeyEvent(KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY, 0))
                        }, 300)
                        wasMusicPlayingBefore = false
                    }
                    
                    isRecording = false
                    result.success(true)
                }
                "registerShortcut" -> {
                    val id = call.argument<String>("id")
                    val label = call.argument<String>("shortLabel")
                    val uri = call.argument<String>("intentUri")

                    if (id != null && label != null && uri != null) {
                        registerDynamicShortcut(id, label, uri)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Faltan datos para el shortcut", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // Este método se dispara al salir de la app (Home/Recientes)
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isMaletaConnected) {
            enterPipMode()
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        if (isInPictureInPictureMode) {
            // Registrar el receptor cuando entramos a PiP
            registerReceiver(stopActionReceiver, IntentFilter("ACTION_STOP_VOICE"))
            updatePipParams(isRecording)
        } else {
            // Desregistrar al salir
            unregisterReceiver(stopActionReceiver)
        }
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }

    private fun enterPipMode(){
         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val aspectRatio = Rational(1, 1) // Proporción cuadrada para la Magic Bag
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(aspectRatio)
                // Opcional: Esto hace que entre a PiP automáticamente al presionar Home
                .setAutoEnterEnabled(true) 
                .build()
                
            val entered = enterPictureInPictureMode(params)
        }
    }


    private fun registerDynamicShortcut(id: String, label: String, uriString: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriString))
        intent.setPackage(packageName)

        val shortcut = ShortcutInfoCompat.Builder(context, id)
            .setShortLabel(label)
            .setLongLabel(label)
            .setIcon(IconCompat.createWithResource(context, R.mipmap.ic_launcher))
            .setIntent(intent)
            .build()

        ShortcutManagerCompat.pushDynamicShortcut(context, shortcut)
    }

    private val stopActionReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        // 4. Enviamos el evento a Flutter por el MethodChannel
        if (isRecording){
            methodChannel?.invokeMethod("onStopFromPip", null)
            updatePipParams(false)
        }
        else{
            voiceTimeoutHandler.removeCallbacksAndMessages(null)
            // INICIAR el auto-cierre
            voiceTimeoutHandler.postDelayed({
                if (isRecording) {
                    methodChannel?.invokeMethod("onStopFromPip", null)// Reutilizamos la función que ya limpia todo
                    updatePipParams(false)
                }
            }, TIMEOUT_VOICE_MS)
            methodChannel?.invokeMethod("onStartFromPip", null)
            updatePipParams(true)
        }
         
    }
    }

    private fun updatePipParams(recording: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val aspect = Rational(1, 1) // Ventana cuadrada
            val iconRes = if (recording) R.drawable.ic_stop else R.drawable.ic_mic
            val title = if (recording) "Detener" else "Hablar"

            // 1. Creamos la "Acción Remota" (el botón)
            val intent = Intent("ACTION_STOP_VOICE")
            val pendingIntent = PendingIntent.getBroadcast(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
            val icon = Icon.createWithResource(this, iconRes)
            
            val action = RemoteAction(icon, title, title, pendingIntent)
            
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(aspect)
                .setActions(listOf(action)) // Aquí inyectas el botón
                .build()

            setPictureInPictureParams(params)
        }
    }
}