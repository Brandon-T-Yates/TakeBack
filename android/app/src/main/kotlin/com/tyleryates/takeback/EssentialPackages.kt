package com.tyleryates.takeback

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build
import android.provider.Settings
import android.telecom.TelecomManager
import android.view.inputmethod.InputMethodManager

/**
 * Packages LOCK IN never sends Home, resolved on the device rather than hard-coded
 * per manufacturer. Each one keeps the phone usable or lets the user turn Unbound off.
 */
object EssentialPackages {
    /** Framework dialogs: app chooser, "open with", crash and not-responding dialogs. */
    private const val FRAMEWORK = "android"

    /** Status bar, notification shade, quick settings, and recents on many devices. AOSP name on every OEM. */
    private const val SYSTEM_UI = "com.android.systemui"

    /** Google sign-in, account chooser, and consent screens. Exempt only as a system app. */
    private const val GOOGLE_PLAY_SERVICES = "com.google.android.gms"

    private const val REQUEST_PERMISSIONS = "android.content.pm.action.REQUEST_PERMISSIONS"
    private const val PICK_IMAGES = "android.provider.action.PICK_IMAGES"
    private const val IN_CALL_SERVICE = "android.telecom.InCallService"
    private const val DIAL_EMERGENCY = "android.intent.action.DIAL_EMERGENCY"

    fun resolve(context: Context): Set<String> {
        val pm = context.packageManager
        val packages = linkedSetOf(context.packageName, FRAMEWORK, SYSTEM_UI)
        val isSystem = { packageName: String -> isSystemApp(pm, packageName) }

        // Home: the user's current launcher, so returning Home always lands somewhere allowed.
        packages.addIfPresent(defaultActivity(pm, Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)))
        // Settings and Accessibility settings: the user must always be able to turn Unbound off.
        packages.addIfPresent(defaultActivity(pm, Intent(Settings.ACTION_SETTINGS)))
        packages.addIfPresent(defaultActivity(pm, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)))

        // System screens that allowed apps hand off to and expect back.
        val handoffs = listOf(
            // Runtime permission prompts (permission controller).
            Intent(REQUEST_PERMISSIONS),
            // Share sheet (a separate package on Android 14+).
            Intent(Intent.ACTION_CHOOSER),
            // Photo Picker.
            Intent(PICK_IMAGES),
            // System file picker (DocumentsUI; also the Files app on some devices).
            Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*"),
        )
        for (intent in handoffs) {
            packages.addIfPresent(HandoffExemption.select(defaultActivity(pm, intent), isSystem))
        }
        packages.addIfPresent(HandoffExemption.select(GOOGLE_PLAY_SERVICES, isSystem))

        // Phone calls: default and system dialers, emergency dialer, and system in-call screens.
        context.getSystemService(TelecomManager::class.java)?.let { telecom ->
            packages.addIfPresent(telecom.defaultDialerPackage)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                packages.addIfPresent(telecom.systemDialerPackage)
            }
        }
        packages.addIfPresent(defaultActivity(pm, Intent(DIAL_EMERGENCY)))
        queryServices(pm, Intent(IN_CALL_SERVICE))
            .mapNotNull { it.serviceInfo?.applicationInfo }
            .filter { it.flags and ApplicationInfo.FLAG_SYSTEM != 0 }
            .forEach { packages.add(it.packageName) }

        // Keyboards draw over allowed apps while typing.
        context.getSystemService(InputMethodManager::class.java)
            ?.enabledInputMethodList
            ?.forEach { packages.add(it.packageName) }

        return packages
    }

    private fun MutableSet<String>.addIfPresent(packageName: String?) {
        if (!packageName.isNullOrEmpty()) add(packageName)
    }

    private fun isSystemApp(pm: PackageManager, packageName: String): Boolean = try {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.getApplicationInfo(packageName, 0)
        }
        HandoffExemption.isSystemFlags(info.flags)
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun defaultActivity(pm: PackageManager, intent: Intent): String? {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.resolveActivity(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        return info?.activityInfo?.packageName
    }

    private fun queryServices(pm: PackageManager, intent: Intent): List<ResolveInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentServices(intent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentServices(intent, 0)
        }
}
