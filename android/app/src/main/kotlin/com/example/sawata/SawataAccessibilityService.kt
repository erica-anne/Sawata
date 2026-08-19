package com.example.sawata

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.example.sawata.ai.AiConfig
import com.example.sawata.ai.InstalledAppsScanWorker
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import java.util.Date

/**
 * Detects the foreground app and blocks it if its package name is covered by
 * Sawatâ's global default blocklist (`blocked_packages`, curated by hand —
 * see [listenForBlockedPackages]) or the signed-in user's own custom
 * blocklist (`users/{uid}/blocked_items`, `category == "App"` entries — see
 * [subscribeToUserBlockedItems]) — but ONLY while the signed-in user's
 * Protection Lock is on (`users/{uid}`'s `protectionActive` field — see
 * [subscribeToUserDoc]). Protection Lock is the single master switch: when
 * it's off, neither the global list nor the user's own personal blocks are
 * enforced (the personal items stay saved in Firestore, just inactive).
 * Sends the user Home, shows [BlockScreenActivity], and logs the attempt to
 * `blocked_attempts`. For a foreground app that *isn't* already blocked, it
 * also checks the app's name/package against [GamblingKeywords] and — on a
 * match — writes a pending suggestion to `users/{uid}/suggestions` instead
 * of blocking; the user confirms or dismisses these from the Blocked Sites &
 * Apps screen.
 *
 * Runs independently of the Flutter engine — it has to work even if the app
 * process was killed in the background while some other app is open — so it
 * talks to Firebase directly via the native Android SDK rather than through
 * a MethodChannel into Dart.
 */
class SawataAccessibilityService : AccessibilityService() {

    private val firestore by lazy { FirebaseFirestore.getInstance() }
    private var blockedPackagesListener: ListenerRegistration? = null
    private var userDocListener: ListenerRegistration? = null
    private var suggestionsListener: ListenerRegistration? = null
    private var userBlockedItemsListener: ListenerRegistration? = null
    private var aiDetectionsListener: ListenerRegistration? = null
    private var authStateListener: FirebaseAuth.AuthStateListener? = null

    // Sawatâ's curated global default blocklist. A legacy doc carrying an
    // `addedByUid` field is pre-fix user-written data that leaked into this
    // collection before per-user scoping existed — it's excluded here so it
    // stops being treated as "blocked for everyone" without deleting it.
    @Volatile private var globalBlockedPackages: Set<String> = emptySet()

    // The signed-in user's own custom app blocks, from
    // users/{uid}/blocked_items. Cleared/re-subscribed on sign-in/sign-out.
    @Volatile private var userBlockedPackages: Set<String> = emptySet()

    // This user's own high-confidence AI gambling detections, from
    // users/{uid}/ai_app_detections (written natively by AppClassificationWorker).
    // Deliberately per-user, never a global/cross-user cache — see
    // AppClassificationWorker's doc comment for why.
    @Volatile private var aiBlockedPackages: Set<String> = emptySet()

    // Mirrors users/{uid}.protectionActive — the Protection Lock toggle on
    // the Protection screen. This is the master switch: when false, NOTHING
    // is blocked, global or personal.
    @Volatile private var protectionActive: Boolean = false

    private val blockedPackages: Set<String>
        get() = if (protectionActive) globalBlockedPackages + userBlockedPackages + aiBlockedPackages else emptySet()

    @Volatile private var linkedGuardianUid: String? = null

    // Packages already suggested (pending or dismissed) — presence alone
    // means "don't suggest again", regardless of the user's decision.
    @Volatile private var suggestedPackages: Set<String> = emptySet()

    // onAccessibilityEvent fires repeatedly for the same foreground app
    // (window/focus churn); debounce so one app-open doesn't trigger the
    // Home-redirect + block screen + Firestore write multiple times.
    private var lastBlockedPackage: String? = null
    private var lastBlockedAt: Long = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        GamblingKeywords.start()
        listenForBlockedPackages()
        listenForSuggestions()

        val uid = FirebaseAuth.getInstance().currentUser?.uid
        subscribeToUserDoc(uid)
        subscribeToUserBlockedItems(uid)
        subscribeToAiDetections(uid)
        val listener = FirebaseAuth.AuthStateListener { auth ->
            subscribeToUserDoc(auth.currentUser?.uid)
            subscribeToUserBlockedItems(auth.currentUser?.uid)
            subscribeToAiDetections(auth.currentUser?.uid)
        }
        authStateListener = listener
        FirebaseAuth.getInstance().addAuthStateListener(listener)
    }

    private fun listenForBlockedPackages() {
        blockedPackagesListener = firestore.collection("blocked_packages")
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) {
                    Log.w(TAG, "blocked_packages listener error", error)
                    return@addSnapshotListener
                }
                globalBlockedPackages = snapshot.documents
                    .filter { it.getString("addedByUid").isNullOrEmpty() }
                    .map { it.id }
                    .toSet()
            }
    }

    /**
     * (Re)subscribes to the given user's `blocked_items` subcollection,
     * always removing any prior registration first so switching users (or
     * signing out) never leaves a stale listener bound to the previous
     * account's data.
     */
    private fun subscribeToUserBlockedItems(uid: String?) {
        userBlockedItemsListener?.remove()
        userBlockedItemsListener = null
        userBlockedPackages = emptySet()
        if (uid == null) return
        userBlockedItemsListener = firestore.collection("users").document(uid)
            .collection("blocked_items")
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) {
                    Log.w(TAG, "user blocked_items listener error", error)
                    return@addSnapshotListener
                }
                userBlockedPackages = snapshot.documents
                    .filter { it.getString("category") == "App" }
                    .mapNotNull { it.getString("packageName") }
                    .filter { it.isNotEmpty() }
                    .toSet()
            }
    }

    /**
     * (Re)subscribes to this user's own `ai_app_detections` subcollection —
     * written natively by AppClassificationWorker. Only classification=="gambling"
     * at/above [AiConfig.HIGH_CONFIDENCE_THRESHOLD] counts; everything else
     * (uncertain, not_gambling, or gambling below the threshold) never
     * affects enforcement here.
     */
    private fun subscribeToAiDetections(uid: String?) {
        aiDetectionsListener?.remove()
        aiDetectionsListener = null
        aiBlockedPackages = emptySet()
        if (uid == null) return
        aiDetectionsListener = firestore.collection("users").document(uid)
            .collection("ai_app_detections")
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) {
                    Log.w(TAG, "ai_app_detections listener error", error)
                    return@addSnapshotListener
                }
                aiBlockedPackages = snapshot.documents
                    .filter {
                        it.getString("classification") == "gambling" &&
                            (it.getDouble("confidence") ?: 0.0) >= AiConfig.HIGH_CONFIDENCE_THRESHOLD
                    }
                    .map { it.id }
                    .toSet()
                Log.i(TAG, "aiBlockedPackages updated: ${aiBlockedPackages.size} entries (uid=$uid)")
            }
    }

    private fun listenForSuggestions() {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        suggestionsListener = firestore.collection("users").document(uid)
            .collection("suggestions")
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) {
                    Log.w(TAG, "suggestions listener error", error)
                    return@addSnapshotListener
                }
                suggestedPackages = snapshot.documents.map { it.id }.toSet()
            }
    }

    /**
     * (Re)subscribes to the given user's `users/{uid}` document, which
     * carries both the linked-guardian uid and the Protection Lock state
     * (`protectionActive`). Always removes any prior registration first so
     * switching users (or signing out) never leaves a stale listener bound
     * to the previous account's data.
     */
    private fun subscribeToUserDoc(uid: String?) {
        userDocListener?.remove()
        userDocListener = null
        linkedGuardianUid = null
        protectionActive = false
        if (uid == null) return
        userDocListener = firestore.collection("users").document(uid)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    Log.w(TAG, "users/$uid listener error", error)
                    return@addSnapshotListener
                }
                linkedGuardianUid = snapshot?.getString("linkedUid")
                val newActive = snapshot?.getBoolean("protectionActive") ?: false
                if (newActive && !protectionActive) {
                    Log.i(TAG, "protectionActive turned ON for uid=$uid — enqueueing installed-apps AI scan")
                    InstalledAppsScanWorker.enqueue(applicationContext, uid)
                }
                protectionActive = newActive
            }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName == applicationContext.packageName) return

        if (packageName !in blockedPackages) {
            maybeSuggestPackage(packageName)
            return
        }

        val now = System.currentTimeMillis()
        if (packageName == lastBlockedPackage && now - lastBlockedAt < DEBOUNCE_MS) return
        lastBlockedPackage = packageName
        lastBlockedAt = now

        val appName = resolveAppName(packageName)
        performGlobalAction(GLOBAL_ACTION_HOME)
        launchBlockScreen(packageName, appName)
        logBlockedAttempt(packageName, appName)
    }

    /**
     * Flags [packageName] as a possible gambling app the user just opened —
     * writes a *pending suggestion*, never blocks it outright. The user
     * confirms or dismisses it from the Blocked Sites & Apps screen.
     */
    private fun maybeSuggestPackage(packageName: String) {
        if (packageName in suggestedPackages) return
        val appName = resolveAppName(packageName)
        if (!GamblingKeywords.matches(appName, packageName)) return

        // Optimistic local update so a rapid re-open before the Firestore
        // listener round-trips doesn't queue a duplicate write.
        suggestedPackages = suggestedPackages + packageName

        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val suggestion = hashMapOf(
            "name" to appName,
            "packageName" to packageName,
            "status" to "pending",
            "suggestedAt" to Date(),
        )
        firestore.collection("users").document(uid)
            .collection("suggestions").document(packageName)
            .set(suggestion)
            .addOnFailureListener { e -> Log.w(TAG, "Failed to write suggestion", e) }
    }

    private fun resolveAppName(packageName: String): String = try {
        packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(packageName, 0)
        ).toString()
    } catch (e: Exception) {
        packageName
    }

    private fun launchBlockScreen(packageName: String, appName: String) {
        val intent = Intent(this, BlockScreenActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(BlockScreenActivity.EXTRA_PACKAGE_NAME, packageName)
            putExtra(BlockScreenActivity.EXTRA_APP_NAME, appName)
        }
        startActivity(intent)
    }

    private fun logBlockedAttempt(packageName: String, appName: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val attempt = hashMapOf(
            "uid" to uid,
            "packageName" to packageName,
            "appName" to appName,
            "timestamp" to Date(),
            "guardianUid" to linkedGuardianUid,
        )
        firestore.collection("blocked_attempts").add(attempt)
            .addOnFailureListener { e -> Log.w(TAG, "Failed to log blocked attempt", e) }
    }

    override fun onInterrupt() {
        // Required override — nothing to clean up mid-flight.
    }

    override fun onDestroy() {
        GamblingKeywords.stop()
        blockedPackagesListener?.remove()
        userDocListener?.remove()
        suggestionsListener?.remove()
        userBlockedItemsListener?.remove()
        aiDetectionsListener?.remove()
        authStateListener?.let { FirebaseAuth.getInstance().removeAuthStateListener(it) }
        super.onDestroy()
    }

    companion object {
        private const val TAG = "SawataAccessibility"
        private const val DEBOUNCE_MS = 2000L
    }
}
