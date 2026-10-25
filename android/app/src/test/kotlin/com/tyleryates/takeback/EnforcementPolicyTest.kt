package com.tyleryates.takeback

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EnforcementPolicyTest {
    private val unbound = "com.tyleryates.takeback"
    private val launcher = "com.example.launcher"
    private val settings = "com.android.settings"
    private val allowed = "com.example.allowed"
    private val blocked = "com.example.blocked"

    private fun snapshot(
        lockRequested: Boolean = true,
        allowedApps: Set<String> = setOf(allowed),
    ) = EnforcementSnapshot(
        lockRequested = lockRequested,
        allowed = allowedApps,
        exempt = setOf(unbound, launcher, settings),
    )

    private fun EnforcementPolicy.home(
        packageName: String,
        at: Long,
        state: EnforcementSnapshot = snapshot(),
        deviceLocked: Boolean = false,
    ) = shouldReturnHome(packageName, state, deviceLocked, at)

    @Test
    fun allowedPackageNeverGoesHome() {
        assertFalse(EnforcementPolicy().home(allowed, 0))
    }

    @Test
    fun blockedPackageGoesHomeOnce() {
        val policy = EnforcementPolicy()
        val actions = listOf(0L, 50L, 120L, 400L).count { policy.home(blocked, it) }
        assertEquals(1, actions)
    }

    @Test
    fun unboundLauncherAndSettingsAreNeverBlocked() {
        val policy = EnforcementPolicy()
        assertFalse(policy.home(unbound, 0))
        assertFalse(policy.home(launcher, 10))
        assertFalse(policy.home(settings, 20))
    }

    @Test
    fun relaunchAfterReturningHomeIsBlockedAgain() {
        val policy = EnforcementPolicy()
        assertTrue(policy.home(blocked, 0))
        assertFalse(policy.home(launcher, 100))
        assertTrue(policy.home(blocked, 300))
    }

    @Test
    fun sameAppLaterIsBlockedAfterDebounceWindow() {
        val policy = EnforcementPolicy(debounceMillis = 1_000)
        assertTrue(policy.home(blocked, 0))
        assertFalse(policy.home(blocked, 999))
        assertTrue(policy.home(blocked, 1_000))
    }

    @Test
    fun unlockedNeverEnforces() {
        val policy = EnforcementPolicy()
        assertFalse(policy.home(blocked, 0, snapshot(lockRequested = false)))
    }

    @Test
    fun unusableSelectionNeverEnforces() {
        val policy = EnforcementPolicy()
        assertFalse(policy.home(blocked, 0, snapshot(allowedApps = emptySet())))
        val tooMany = (1..51).map { "app.$it" }.toSet()
        assertFalse(policy.home(blocked, 10, snapshot(allowedApps = tooMany)))
    }

    @Test
    fun lockScreenSurfacesAreNeverBlocked() {
        val policy = EnforcementPolicy()
        assertFalse(policy.home(blocked, 0, deviceLocked = true))
        assertTrue(policy.home(blocked, 10))
    }
}
