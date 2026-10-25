package com.tyleryates.unbound

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.drawable.Drawable
import android.os.Build

data class LaunchableApp(val packageName: String, val label: String)

/** User-facing apps with a launcher activity. Requires only the manifest launcher query. */
object LaunchableApps {
    fun list(context: Context): List<LaunchableApp> {
        val pm = context.packageManager
        val own = context.packageName
        return query(pm, null)
            .asSequence()
            .mapNotNull { info ->
                val pkg = info.activityInfo?.packageName ?: return@mapNotNull null
                if (pkg == own || info.activityInfo?.enabled == false) return@mapNotNull null
                val label = info.loadLabel(pm)?.toString()?.trim().orEmpty()
                if (label.isEmpty()) null else LaunchableApp(pkg, label)
            }
            .distinctBy { it.packageName }
            .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.label })
            .toList()
    }

    fun isLaunchable(context: Context, packageName: String): Boolean =
        packageName != context.packageName &&
            query(context.packageManager, packageName).isNotEmpty()

    fun label(context: Context, packageName: String): String? =
        query(context.packageManager, packageName).firstOrNull()
            ?.loadLabel(context.packageManager)?.toString()

    fun icon(context: Context, packageName: String): Drawable? = try {
        context.packageManager.getApplicationIcon(packageName)
    } catch (_: PackageManager.NameNotFoundException) {
        null
    }

    private fun query(pm: PackageManager, packageName: String?): List<ResolveInfo> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        if (packageName != null) intent.setPackage(packageName)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }
    }
}
