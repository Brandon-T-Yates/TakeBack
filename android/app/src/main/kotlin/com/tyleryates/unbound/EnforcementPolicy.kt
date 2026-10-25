package com.tyleryates.unbound

/** What enforcement needs to know at the moment an app comes to the foreground. */
data class EnforcementSnapshot(
    val lockRequested: Boolean,
    val allowed: Set<String>,
    val exempt: Set<String>,
) {
    val active: Boolean
        get() = lockRequested &&
            allowed.size in AndroidAllowedAppsStore.MIN_APPS..AndroidAllowedAppsStore.MAX_APPS
}

/**
 * Decides whether a foreground package must be sent Home. Pure logic so it can be
 * unit-tested without Android. One blocked launch produces at most one Home action.
 */
class EnforcementPolicy(private val debounceMillis: Long = DEFAULT_DEBOUNCE_MILLIS) {
    private var lastBlocked: String? = null
    private var lastBlockedAt = 0L

    fun shouldReturnHome(
        packageName: String,
        snapshot: EnforcementSnapshot,
        deviceLocked: Boolean,
        nowMillis: Long,
    ): Boolean {
        if (!snapshot.active) {
            lastBlocked = null
            return false
        }
        // Anything shown over the lock screen (calls, emergency dialer, camera) is never blocked.
        if (deviceLocked) return false
        if (packageName in snapshot.exempt || packageName in snapshot.allowed) {
            lastBlocked = null
            return false
        }
        if (packageName == lastBlocked && nowMillis - lastBlockedAt < debounceMillis) return false
        lastBlocked = packageName
        lastBlockedAt = nowMillis
        return true
    }

    companion object {
        const val DEFAULT_DEBOUNCE_MILLIS = 1_500L
    }
}
