package com.tyleryates.unbound

import android.content.pm.ApplicationInfo

/**
 * System screens that allowed apps hand off to (permission prompts, share sheet, Photo Picker,
 * file picker, Google sign-in). A package is exempt only if it is system-owned and is the
 * handler the device actually resolved, never merely because it can handle the intent.
 */
object HandoffExemption {
    private const val SYSTEM_FLAGS =
        ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP

    fun isSystemFlags(flags: Int): Boolean = flags and SYSTEM_FLAGS != 0

    fun select(resolvedHandler: String?, isSystemApp: (String) -> Boolean): String? =
        resolvedHandler?.takeIf { it.isNotEmpty() && isSystemApp(it) }
}
