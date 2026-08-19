package com.example.sawata

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

/**
 * Enumerates normal, user-launchable installed apps (icon + display name +
 * package name) for the "Choose an App" picker in Blocked Sites & Apps —
 * see lib/screens/user/protection/widgets/add_blocked_item_sheet.dart.
 *
 * Scoped to `ACTION_MAIN`/`CATEGORY_LAUNCHER` (apps with a home-screen icon)
 * rather than every installed package: this is both what a normal user
 * expects to pick from and the minimal query Android 11+'s package
 * visibility rules allow without the sensitive QUERY_ALL_PACKAGES
 * permission — see the matching `<queries>` entry in AndroidManifest.xml.
 */
object InstalledAppsProvider {
    private const val ICON_SIZE_PX = 96

    fun list(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val ownPackage = context.packageName

        return pm.queryIntentActivities(launcherIntent, 0)
            .asSequence()
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != ownPackage }
            .map { appInfo -> appInfo to pm.getApplicationLabel(appInfo).toString() }
            .sortedBy { (_, label) -> label.lowercase() }
            .map { (appInfo, label) ->
                mapOf(
                    "name" to label,
                    "packageName" to appInfo.packageName,
                    "icon" to iconBytes(pm, appInfo),
                )
            }
            .toList()
    }

    /** Best-effort — a missing/unreadable icon shouldn't drop the app from the list. */
    private fun iconBytes(pm: PackageManager, appInfo: ApplicationInfo): ByteArray? = try {
        drawableToPngBytes(pm.getApplicationIcon(appInfo), ICON_SIZE_PX)
    } catch (e: Exception) {
        null
    }

    private fun drawableToPngBytes(drawable: Drawable, sizePx: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        bitmap.recycle()
        return stream.toByteArray()
    }
}
