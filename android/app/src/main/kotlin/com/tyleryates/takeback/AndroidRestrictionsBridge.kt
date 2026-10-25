package com.tyleryates.takeback

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** App selection, the requested lock flag, and Accessibility setup. Never locks on its own. */
class AndroidRestrictionsBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val store = AndroidAllowedAppsStore(activity)
    private var pendingSelection: MethodChannel.Result? = null

    private val serviceListener: () -> Unit = {
        activity.runOnUiThread { channel.invokeMethod("setupChanged", setupState()) }
    }

    init {
        channel.setMethodCallHandler(this)
        UnboundAccessibilityService.addListener(serviceListener)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSetupState" -> result.success(setupState())
            "selectAllowedApps" -> presentPicker(result)
            "getAllowedApps" -> result.success(allowedApps())
            "openAccessibilitySettings" -> result.success(openAccessibilitySettings())
            "isLockdownEnabled" -> result.success(store.lockdownEnabled)
            "enableLockdown" -> setLockdown(true, result)
            "disableLockdown" -> setLockdown(false, result)
            "toggleLockdown" -> setLockdown(!store.lockdownEnabled, result)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode != PICKER_REQUEST) return
        val result = pendingSelection ?: return
        pendingSelection = null
        result.success(if (resultCode == Activity.RESULT_OK) "selected" else "cancelled")
    }

    fun dispose() {
        UnboundAccessibilityService.removeListener(serviceListener)
        channel.setMethodCallHandler(null)
        pendingSelection?.success("cancelled")
        pendingSelection = null
    }

    private fun currentPackages(): Set<String> =
        store.prune { LaunchableApps.isLaunchable(activity, it) }

    private fun isUsable(count: Int) =
        count in AndroidAllowedAppsStore.MIN_APPS..AndroidAllowedAppsStore.MAX_APPS

    private fun setupState(): Map<String, Any> {
        val count = currentPackages().size
        val usable = isUsable(count)
        if (!usable && store.lockdownEnabled) store.lockdownEnabled = false
        val accessibilityEnabled = UnboundAccessibilityService.isEnabledInSettings(activity)
        val accessibilityRunning = accessibilityEnabled && UnboundAccessibilityService.running
        if (store.lockdownEnabled && !accessibilityEnabled) {
            // Access was turned off while locked in: nothing is being blocked, so stop claiming LOCK IN.
            store.lockdownEnabled = false
            store.accessInterrupted = true
        }
        val requested = store.lockdownEnabled
        val enforcing = requested && usable && accessibilityRunning
        val state = mutableMapOf<String, Any>(
            "available" to true,
            "authorization" to "authorized",
            "hasSavedSelection" to (count > 0),
            "applicationCount" to count,
            "selectionUsable" to usable,
            "restrictionMode" to "android",
            "accessibilityEnabled" to accessibilityEnabled,
            "accessibilityRunning" to accessibilityRunning,
            "accessInterrupted" to store.accessInterrupted,
            "enforcing" to enforcing,
            "lockdownState" to when {
                !requested -> "unlocked"
                enforcing -> "locked"
                else -> "error"
            },
            "revision" to store.revision,
        )
        if (requested && !enforcing) {
            // Enabled in Settings but not connected, e.g. after Android stopped the service.
            state["restrictionMessage"] =
                "Android paused Unbound’s access, so apps aren’t being blocked. " +
                "Tap UNLOCK, then LOCK IN to set it up again."
        }
        return state
    }

    private fun allowedApps(): List<Map<String, String>> =
        currentPackages()
            .map { mapOf("packageName" to it, "label" to (LaunchableApps.label(activity, it) ?: it)) }
            .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.getValue("label") })

    private fun presentPicker(result: MethodChannel.Result) {
        if (pendingSelection != null) {
            result.error("selection_in_progress", "App selection is already open.", null)
            return
        }
        if (store.lockdownEnabled) {
            result.error("unlock_required", "Unlock Unbound before changing your allowed apps.", null)
            return
        }
        try {
            pendingSelection = result
            activity.startActivityForResult(
                Intent(activity, AllowedAppsActivity::class.java),
                PICKER_REQUEST,
            )
        } catch (_: ActivityNotFoundException) {
            pendingSelection = null
            result.success("unavailable")
        }
    }

    /** Opens Unbound's own Accessibility page where supported, otherwise the general list. */
    private fun openAccessibilitySettings(): Boolean {
        val component = UnboundAccessibilityService.component(activity).flattenToString()
        val intents = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                add(
                    Intent(ACTION_ACCESSIBILITY_DETAILS_SETTINGS)
                        .putExtra(Intent.EXTRA_COMPONENT_NAME, component),
                )
            }
            add(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    .putExtra(EXTRA_FRAGMENT_ARG_KEY, component)
                    .putExtra(
                        EXTRA_SHOW_FRAGMENT_ARGUMENTS,
                        Bundle().apply { putString(EXTRA_FRAGMENT_ARG_KEY, component) },
                    ),
            )
        }
        for (intent in intents) {
            try {
                activity.startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
        return false
    }

    private fun setLockdown(enabled: Boolean, result: MethodChannel.Result) {
        if (!enabled) {
            // UNLOCK always succeeds and stops enforcement immediately, even if other reads fail.
            store.lockdownEnabled = false
            result.success(runCatching { setupState() }.getOrNull())
            return
        }
        if (!isUsable(currentPackages().size)) {
            result.error("selection_required", "Choose 1–50 apps first.", null)
            return
        }
        if (!UnboundAccessibilityService.isEnabledInSettings(activity) ||
            !UnboundAccessibilityService.running
        ) {
            result.error(
                "accessibility_required",
                "Turn on Unbound’s Accessibility access to lock in.",
                null,
            )
            return
        }
        store.accessInterrupted = false
        store.lockdownEnabled = true
        result.success(setupState())
    }

    companion object {
        const val CHANNEL = "unbound/android_restrictions"
        private const val PICKER_REQUEST = 4127
        /** Settings' per-service page (Android 11+). Not in the public SDK, so it is tried first with a fallback. */
        private const val ACTION_ACCESSIBILITY_DETAILS_SETTINGS =
            "android.settings.ACCESSIBILITY_DETAILS_SETTINGS"
        private const val EXTRA_FRAGMENT_ARG_KEY = ":settings:fragment_args_key"
        private const val EXTRA_SHOW_FRAGMENT_ARGUMENTS = ":settings:show_fragment_args"
    }
}
