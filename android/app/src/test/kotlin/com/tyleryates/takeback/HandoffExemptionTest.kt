package com.tyleryates.takeback

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HandoffExemptionTest {
    private val systemApps = setOf(
        "com.google.android.documentsui",
        "com.google.android.providers.media.module",
        "com.google.android.permissioncontroller",
        "com.google.android.gms",
    )
    private val isSystem = { pkg: String -> pkg in systemApps }

    @Test
    fun resolvedSystemHandlerIsExempt() {
        assertEquals(
            "com.google.android.documentsui",
            HandoffExemption.select("com.google.android.documentsui", isSystem),
        )
        assertEquals(
            "com.google.android.providers.media.module",
            HandoffExemption.select("com.google.android.providers.media.module", isSystem),
        )
    }

    @Test
    fun resolvedUserAppIsNeverExempt() {
        // e.g. a third-party file manager set as the default document handler.
        assertNull(HandoffExemption.select("com.example.filemanager", isSystem))
    }

    @Test
    fun nothingResolvedMeansNoExemption() {
        assertNull(HandoffExemption.select(null, isSystem))
        assertNull(HandoffExemption.select("", isSystem))
    }

    @Test
    fun systemFlagsIncludeUpdatedSystemApps() {
        assertTrue(HandoffExemption.isSystemFlags(android.content.pm.ApplicationInfo.FLAG_SYSTEM))
        assertTrue(
            HandoffExemption.isSystemFlags(android.content.pm.ApplicationInfo.FLAG_UPDATED_SYSTEM_APP),
        )
        assertFalse(HandoffExemption.isSystemFlags(0))
    }

    @Test
    fun handoffExemptionsDoNotLetOrdinaryAppsThrough() {
        val policy = EnforcementPolicy()
        val exempt = listOf("com.google.android.documentsui", "com.android.chrome", null)
            .mapNotNull { HandoffExemption.select(it, isSystem) }
            .toSet()
        val snapshot = EnforcementSnapshot(
            lockRequested = true,
            allowed = setOf("com.example.notes"),
            exempt = exempt,
        )
        assertFalse(policy.shouldReturnHome("com.google.android.documentsui", snapshot, false, 1_000L))
        assertTrue(policy.shouldReturnHome("com.android.chrome", snapshot, false, 2_000L))
    }
}
