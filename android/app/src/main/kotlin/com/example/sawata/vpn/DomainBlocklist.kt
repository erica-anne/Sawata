package com.example.sawata.vpn

import android.content.Context
import android.util.Log
import com.example.sawata.GamblingKeywords
import com.example.sawata.ai.AiConfig
import com.example.sawata.ai.DomainClassificationWorker
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import java.util.ArrayDeque
import java.util.Collections
import java.util.concurrent.Executors

/**
 * In-memory cache of the effective blocked-domain set — the union of
 * Sawatâ's global default blocklist (`blocked_domains`, curated by hand) and
 * the signed-in user's own custom website blocks (`users/{uid}/blocked_items`,
 * `category == "Website"` entries) — but ONLY while the signed-in user's
 * Protection Lock is on (`users/{uid}`'s `protectionActive` field — see
 * [subscribeToProtectionState]). Protection Lock is the single master
 * switch: when it's off, neither list is enforced (personal entries stay
 * saved in Firestore, just inactive). [SawataVpnService] is also stopped
 * outright when Protection Lock turns off (see `protection_screen.dart`'s
 * `_turnOffProtection`) — this gate is a second, defense-in-depth layer so
 * that even if the VPN process somehow keeps running, it blocks nothing.
 * Same shape as `blockedPackages` in `SawataAccessibilityService` — reads
 * Firestore directly through the native Firebase SDK since
 * [SawataVpnService] also runs independently of the Flutter engine.
 */
object DomainBlocklist {
    private const val TAG = "SawataDomainBlocklist"

    // A legacy doc carrying an `addedByUid` field is pre-fix user-written
    // data that leaked into this collection before per-user scoping
    // existed — excluded here so it stops being treated as global, without
    // deleting it.
    @Volatile private var globalDomains: Set<String> = emptySet()

    // The signed-in user's own custom domain blocks. Cleared/re-subscribed
    // on sign-in/sign-out.
    @Volatile private var userDomains: Set<String> = emptySet()

    // This user's own high-confidence AI gambling detections, from
    // users/{uid}/ai_domain_detections (written natively by
    // DomainClassificationWorker). Per-user, never a global/cross-user cache.
    @Volatile private var aiBlockedDomains: Set<String> = emptySet()

    // Mirrors users/{uid}.protectionActive — the Protection Lock toggle on
    // the Protection screen. This is the master switch: when false, NOTHING
    // is blocked, global or personal.
    @Volatile private var protectionActive: Boolean = false

    private var registration: ListenerRegistration? = null
    private var userRegistration: ListenerRegistration? = null
    private var userDocRegistration: ListenerRegistration? = null
    private var aiDomainRegistration: ListenerRegistration? = null
    private var authStateListener: FirebaseAuth.AuthStateListener? = null

    // Off-thread dispatch for maybeQueueForClassification — WorkManager's
    // enqueueUniqueWork() does local disk I/O, which has no business running
    // on UdpRelay's packet-handling thread.
    private val classificationExecutor = Executors.newSingleThreadExecutor()

    // Bounded, in-memory-only dedup cache of domains already queued/classified
    // this session, so repeated DNS lookups for the same domain (very common)
    // don't re-enqueue work every time. Capped, not persisted — a restart
    // just means a handful of domains might get looked at again, which is
    // harmless (DomainClassificationWorker itself re-checks the Firestore
    // cache before calling Gemini).
    private val recentCandidates = Collections.synchronizedSet(LinkedHashSet<String>())
    private const val CANDIDATE_CACHE_CAP = 200

    // Simple sliding-window rate limit on new classification enqueues, so a
    // page with many keyword-matching subdomains can't burst a pile of
    // WorkManager jobs (and Gemini calls) at once.
    private val enqueueTimestamps = ArrayDeque<Long>()
    private const val RATE_LIMIT_WINDOW_MS = 60_000L
    private const val RATE_LIMIT_MAX_PER_WINDOW = 10

    fun start() {
        if (registration != null) return
        registration = FirebaseFirestore.getInstance()
            .collection("blocked_domains")
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) {
                    Log.w(TAG, "blocked_domains listener error", error)
                    return@addSnapshotListener
                }
                globalDomains = snapshot.documents
                    .filter { it.getString("addedByUid").isNullOrEmpty() }
                    .map { it.id.lowercase() }
                    .toSet()
            }

        val uid = FirebaseAuth.getInstance().currentUser?.uid
        subscribeToUserDomains(uid)
        subscribeToProtectionState(uid)
        subscribeToAiDomainDetections(uid)
        val listener = FirebaseAuth.AuthStateListener { auth ->
            subscribeToUserDomains(auth.currentUser?.uid)
            subscribeToProtectionState(auth.currentUser?.uid)
            subscribeToAiDomainDetections(auth.currentUser?.uid)
        }
        authStateListener = listener
        FirebaseAuth.getInstance().addAuthStateListener(listener)
    }

    /**
     * (Re)subscribes to this user's own `ai_domain_detections` subcollection
     * — written natively by DomainClassificationWorker. Same threshold rule
     * as SawataAccessibilityService's app-side equivalent.
     */
    private fun subscribeToAiDomainDetections(uid: String?) {
        aiDomainRegistration?.remove()
        aiDomainRegistration = null
        aiBlockedDomains = emptySet()
        if (uid == null) return
        aiDomainRegistration = FirebaseFirestore.getInstance()
            .collection("users").document(uid)
            .collection("ai_domain_detections")
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) {
                    Log.w(TAG, "ai_domain_detections listener error", error)
                    return@addSnapshotListener
                }
                aiBlockedDomains = snapshot.documents
                    .filter {
                        it.getString("classification") == "gambling" &&
                            (it.getDouble("confidence") ?: 0.0) >= AiConfig.HIGH_CONFIDENCE_THRESHOLD
                    }
                    .map { it.id }
                    .toSet()
                Log.i(TAG, "aiBlockedDomains updated: ${aiBlockedDomains.size} entries (uid=$uid)")
            }
    }

    /**
     * (Re)subscribes to the given user's `blocked_items` subcollection,
     * always removing any prior registration first so switching users (or
     * signing out) never leaves a stale listener bound to the previous
     * account's data.
     */
    private fun subscribeToUserDomains(uid: String?) {
        userRegistration?.remove()
        userRegistration = null
        userDomains = emptySet()
        if (uid == null) return
        userRegistration = FirebaseFirestore.getInstance()
            .collection("users").document(uid)
            .collection("blocked_items")
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) {
                    Log.w(TAG, "user blocked_items listener error", error)
                    return@addSnapshotListener
                }
                userDomains = snapshot.documents
                    .filter { it.getString("category") == "Website" }
                    .mapNotNull { it.getString("name")?.trim()?.lowercase() }
                    .filter { it.isNotEmpty() }
                    .toSet()
            }
    }

    /**
     * (Re)subscribes to the given user's `users/{uid}` document for the
     * Protection Lock state, always removing any prior registration first
     * so switching users (or signing out) never leaves a stale listener
     * bound to the previous account's data.
     */
    private fun subscribeToProtectionState(uid: String?) {
        userDocRegistration?.remove()
        userDocRegistration = null
        protectionActive = false
        if (uid == null) return
        userDocRegistration = FirebaseFirestore.getInstance()
            .collection("users").document(uid)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    Log.w(TAG, "users/$uid listener error", error)
                    return@addSnapshotListener
                }
                protectionActive = snapshot?.getBoolean("protectionActive") ?: false
                // Diagnostic only — confirms the Protection Lock toggle actually
                // reaches this listener in real time. Filter logcat on this TAG
                // while testing to see the exact moment (and value) of the change.
                Log.i(TAG, "protectionActive=$protectionActive (uid=$uid)")
            }
    }

    fun stop() {
        registration?.remove()
        registration = null
        userRegistration?.remove()
        userRegistration = null
        userDocRegistration?.remove()
        userDocRegistration = null
        aiDomainRegistration?.remove()
        aiDomainRegistration = null
        authStateListener?.let { FirebaseAuth.getInstance().removeAuthStateListener(it) }
        authStateListener = null
        globalDomains = emptySet()
        userDomains = emptySet()
        aiBlockedDomains = emptySet()
        protectionActive = false
    }

    /** True if [host] (or any parent domain of it) is in the blocklist. */
    fun isBlocked(host: String): Boolean {
        if (!protectionActive) return false
        val normalized = host.trimEnd('.').lowercase()
        val matchesGlobal = globalDomains.any { normalized == it || normalized.endsWith(".$it") }
        val matchesPersonal = userDomains.any { normalized == it || normalized.endsWith(".$it") }
        val matchesAi = aiBlockedDomains.any { normalized == it || normalized.endsWith(".$it") }
        val blocked = matchesGlobal || matchesPersonal || matchesAi
        // Diagnostic only — logs *why* a query was blocked (global gambling
        // list vs. a personal blocked_items entry vs. an AI detection) so a
        // real-device test can tell a genuine logic bug apart from browser
        // DNS caching, without logging every allowed (non-blocked) query.
        if (blocked) {
            Log.i(
                TAG,
                "isBlocked($normalized)=true global=$matchesGlobal personal=$matchesPersonal ai=$matchesAi protectionActive=$protectionActive",
            )
        }
        return blocked
    }

    /**
     * Called from UdpRelay's packet-handling thread right after a DNS query
     * is confirmed NOT blocked. Must stay cheap and synchronous — everything
     * here is an in-memory check; the only I/O (WorkManager's local enqueue)
     * is dispatched onto [classificationExecutor], off the caller's thread.
     * Gemini itself is never reachable from this call path at all — that
     * only happens later, inside DomainClassificationWorker.
     */
    fun maybeQueueForClassification(context: Context, host: String) {
        if (!protectionActive) return
        val normalized = host.trimEnd('.').lowercase()
        if (globalDomains.contains(normalized) || userDomains.contains(normalized)) return
        if (aiBlockedDomains.contains(normalized)) return
        // Cheap keyword prefilter — most ordinary DNS lookups (CDNs, ads,
        // analytics, every other app's traffic sharing this tunnel) never
        // get anywhere near a Firestore write or a Gemini call.
        if (!GamblingKeywords.matchesText(normalized)) return

        synchronized(recentCandidates) {
            if (recentCandidates.contains(normalized)) return
            if (recentCandidates.size >= CANDIDATE_CACHE_CAP) {
                val oldest = recentCandidates.firstOrNull()
                if (oldest != null) recentCandidates.remove(oldest)
            }
            recentCandidates.add(normalized)
        }

        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return

        val allowed = synchronized(enqueueTimestamps) {
            val now = System.currentTimeMillis()
            while (enqueueTimestamps.isNotEmpty() && now - enqueueTimestamps.first() > RATE_LIMIT_WINDOW_MS) {
                enqueueTimestamps.removeFirst()
            }
            if (enqueueTimestamps.size >= RATE_LIMIT_MAX_PER_WINDOW) {
                false
            } else {
                enqueueTimestamps.addLast(now)
                true
            }
        }
        if (!allowed) {
            Log.i(TAG, "AI domain classification rate-limited, skipping $normalized")
            return
        }

        Log.i(TAG, "Queueing domain for AI classification: $normalized uid=$uid")
        val appContext = context.applicationContext
        classificationExecutor.execute {
            DomainClassificationWorker.enqueue(appContext, uid, normalized)
        }
    }
}
