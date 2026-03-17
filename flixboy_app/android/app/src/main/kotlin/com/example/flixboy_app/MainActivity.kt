// android/app/src/main/kotlin/com/example/flixboy_app/MainActivity.kt
//
// INSTRUCCIONES:
// 1. Abre: android/app/src/main/kotlin/com/example/flixboy_app/MainActivity.kt
//    (la ruta puede variar según tu package name, busca el archivo MainActivity.kt)
// 2. Reemplaza TODO el contenido con este código.

package com.example.flixboy_app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Canal de comunicación Flutter ↔ Android nativo
    private val SECURITY_CHANNEL = "com.flixboy.app/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── BLOQUEAR CAPTURAS DE PANTALLA ──────────────────────
        // FLAG_SECURE hace que:
        //   • No se puedan tomar screenshots
        //   • No se pueda grabar la pantalla
        //   • La app aparezca en blanco en el app switcher
        //   • No se pueda capturar con herramientas de accesibilidad
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal para que Flutter pueda activar/desactivar FLAG_SECURE dinámicamente
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURITY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureScreen" -> {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE
                    )
                    result.success(true)
                }
                "disableSecureScreen" -> {
                    // Solo usar en pantallas donde necesites permitir screenshots
                    // (por ejemplo, si agregas una función de compartir)
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}