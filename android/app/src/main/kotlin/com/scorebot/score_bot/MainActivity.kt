package com.scorebot.score_bot

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Node
import java.nio.charset.StandardCharsets

class MainActivity : FlutterActivity(), MessageClient.OnMessageReceivedListener {

    private val CHANNEL = "com.scorebot.score_bot/wearable"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendMessage" -> {
                    val path = call.argument<String>("path") ?: "/match/sync"
                    val data = call.argument<String>("data") ?: ""
                    sendWearableMessage(path, data, result)
                }
                "checkConnectedNodes" -> {
                    getConnectedNodes(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            Wearable.getMessageClient(this).addListener(this)
        } catch (e: Exception) {
            // Ignorer si les Play Services Wearable ne sont pas disponibles sur le device
        }
    }

    override fun onPause() {
        super.onPause()
        try {
            Wearable.getMessageClient(this).removeListener(this)
        } catch (e: Exception) {
            // Ignorer
        }
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        val path = messageEvent.path
        val data = String(messageEvent.data, StandardCharsets.UTF_8)
        
        runOnUiThread {
            methodChannel?.invokeMethod("onMessageReceived", mapOf(
                "path" to path,
                "data" to data,
                "sourceNodeId" to messageEvent.sourceNodeId
            ))
        }
    }

    private fun sendWearableMessage(path: String, data: String, result: MethodChannel.Result) {
        val nodeClient = Wearable.getNodeClient(this)
        val messageClient = Wearable.getMessageClient(this)
        val bytes = data.toByteArray(StandardCharsets.UTF_8)

        nodeClient.connectedNodes
            .addOnSuccessListener { nodes: List<Node> ->
                if (nodes.isEmpty()) {
                    result.success(mapOf("delivered" to false, "nodeCount" to 0))
                    return@addOnSuccessListener
                }

                var successCount = 0
                for (node in nodes) {
                    messageClient.sendMessage(node.id, path, bytes)
                        .addOnSuccessListener {
                            successCount++
                        }
                }
                result.success(mapOf("delivered" to true, "nodeCount" to nodes.size))
            }
            .addOnFailureListener { exception ->
                result.error("WEARABLE_ERROR", exception.message, null)
            }
    }

    private fun getConnectedNodes(result: MethodChannel.Result) {
        val nodeClient = Wearable.getNodeClient(this)
        nodeClient.connectedNodes
            .addOnSuccessListener { nodes: List<Node> ->
                val nodeList = nodes.map { mapOf("id" to it.id, "displayName" to it.displayName) }
                result.success(nodeList)
            }
            .addOnFailureListener { exception ->
                result.error("WEARABLE_ERROR", exception.message, null)
            }
    }
}
