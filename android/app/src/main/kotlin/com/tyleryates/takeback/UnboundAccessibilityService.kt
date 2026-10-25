package com.tyleryates.takeback

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent

/**
 * LOCK IN enforcement. Receives only window-state changes and reads only the package
 * name of the app coming to the foreground. When LOCK IN is on and that package is not
 * allowed, it performs the Home action. It never reads window content or keeps history.
 */
class UnboundAccessibilityService : AccessibilityService() {
    private lateinit var store: AndroidAllowedAppsStore
    private val policy = EnforcementPolicy()
    private var exempt: Set<String> = emptySet()
    private var exemptResolvedAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        store = AndroidAllowedAppsStore(this)
        refreshPackages()
        setRunning(true)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        if (!::store.isInitialized || !store.lockdownEnabled) return
        val now = SystemClock.elapsedRealtime()
        if (now - exemptResolvedAt > REFRESH_MILLIS) refreshPackages()
        val snapshot = EnforcementSnapshot(
            lockRequested = store.lockdownEnabled,
            allowed = store.packages,
            exempt = exempt,
        )
        val deviceLocked = getSystemService(KeyguardManager::class.java)?.isKeyguardLocked == true
        if (policy.shouldReturnHome(packageName, snapshot, deviceLocked, now)) {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        setRunning(false)
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        setRunning(false)
        super.onDestroy()
    }

    private fun refreshPackages() {
        exempt = EssentialPackages.resolve(this)
        store.prune { LaunchableApps.isLaunchable(this, it) }
        exemptResolvedAt = SystemClock.elapsedRealtime()
    }

    companion object {
        private const val REFRESH_MILLIS = 30_000L
        private val listeners = mutableSetOf<() -> Unit>()

        /** True while Android has this service bound in Unbound's process. */
        @Volatile
        var running: Boolean = false
            private set

        private fun setRunning(value: Boolean) {
            if (running == value) return
            running = value
            listeners.toList().forEach { it() }
        }

        fun addListener(listener: () -> Unit) {
            listeners += listener
        }

        fun removeListener(listener: () -> Unit) {
            listeners -= listener
        }

        fun component(context: Context) =
            ComponentName(context, UnboundAccessibilityService::class.java)

        /** Reads the system's enabled-services setting, not any record of having asked. */
        fun isEnabledInSettings(context: Context): Boolean {
            val expected = component(context)
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            return enabled.split(':').any { ComponentName.unflattenFromString(it) == expected }
        }
    }
}
