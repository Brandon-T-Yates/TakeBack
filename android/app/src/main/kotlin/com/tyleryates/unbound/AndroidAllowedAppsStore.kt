package com.tyleryates.unbound

import android.content.Context

/** Android allowlist only. iOS selection tokens are stored separately by the iOS app. */
class AndroidAllowedAppsStore(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    /** An empty set means no saved selection; zero apps is never a saved allowlist. */
    val packages: Set<String>
        get() = prefs.getStringSet(KEY_PACKAGES, null)?.toSet().orEmpty()

    val hasSavedSelection: Boolean
        get() = packages.isNotEmpty()

    val revision: Int
        get() = prefs.getInt(KEY_REVISION, 0)

    var lockdownEnabled: Boolean
        get() = prefs.getBoolean(KEY_LOCKDOWN, false)
        set(value) {
            prefs.edit()
                .putBoolean(KEY_LOCKDOWN, value)
                .putInt(KEY_REVISION, revision + 1)
                .commit()
        }

    /** Set when LOCK IN was turned off because Accessibility access was turned off. */
    var accessInterrupted: Boolean
        get() = prefs.getBoolean(KEY_ACCESS_INTERRUPTED, false)
        set(value) {
            prefs.edit().putBoolean(KEY_ACCESS_INTERRUPTED, value).commit()
        }

    fun save(selection: Set<String>) {
        require(selection.size in MIN_APPS..MAX_APPS) { "Choose $MIN_APPS–$MAX_APPS apps." }
        prefs.edit()
            .putStringSet(KEY_PACKAGES, HashSet(selection))
            .putInt(KEY_REVISION, revision + 1)
            .commit()
    }

    fun clear() {
        prefs.edit()
            .remove(KEY_PACKAGES)
            .putBoolean(KEY_LOCKDOWN, false)
            .putInt(KEY_REVISION, revision + 1)
            .commit()
    }

    /** Drops packages that are no longer launchable so counts match the device. */
    fun prune(isLaunchable: (String) -> Boolean): Set<String> {
        val stored = packages
        val kept = stored.filterTo(HashSet(), isLaunchable)
        if (kept.size != stored.size) {
            if (kept.isEmpty()) clear() else save(kept.take(MAX_APPS).toSet())
        }
        return kept
    }

    companion object {
        const val MIN_APPS = 1
        const val MAX_APPS = 50
        private const val PREFERENCES = "unbound_android_restrictions"
        private const val KEY_PACKAGES = "allowed_packages"
        private const val KEY_LOCKDOWN = "lockdown_enabled"
        private const val KEY_REVISION = "revision"
        private const val KEY_ACCESS_INTERRUPTED = "access_interrupted"
    }
}
