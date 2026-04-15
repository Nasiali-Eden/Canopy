# Authentication Debugging Guide

## Quick Log Filtering

Use these filters in your IDE's debug console to focus on specific components:

### Firebase Initialization
```
[Firebase]
```
Shows Firebase initialization attempts, timeouts, and configuration.

### Firestore Configuration
```
[Firestore]
```
Shows Firestore settings, network status, and readiness checks.

### Splash Screen Flow
```
[Splash]
```
Shows auth state restoration, Firestore routing, and offline fallback.

### Login Flow
```
[Login]
```
Shows sign-in attempts, routing decisions, and error handling.

### Auth Service
```
[AuthService]
```
Shows retry logic, token refresh, and error classification.

### All Auth-Related
```
\[.*\]
```
(Regex) Shows all prefixed logs for complete auth flow visibility.

---

## Common Issues & Solutions

### Issue: "Sign in failed after 3 attempts"

**Possible Causes:**

1. **Network Error (Retryable)**
   - Look for: `[AuthService] Sign in Firebase error on attempt X: network-request-failed`
   - Solution: Check internet connection, retry sign-in
   - Expected: Should succeed on retry

2. **Auth Error (Non-Retryable)**
   - Look for: `[AuthService] Not a network error (wrong-password), giving up`
   - Solution: Check email/password, reset password if needed
   - Expected: Should show specific error message

3. **Timeout Error**
   - Look for: `[AuthService] Sign in Firebase error on attempt X: network-timeout`
   - Solution: Check network speed, retry sign-in
   - Expected: Should succeed on retry

4. **Firebase Not Initialized**
   - Look for: `[Firebase] ❌ Failed after 3 attempts`
   - Solution: Check Firebase configuration, restart app
   - Expected: Should see `[Firebase] ✅ Initialized successfully`

---

### Issue: "User stuck on splash screen"

**Possible Causes:**

1. **Auth State Not Restoring**
   - Look for: `[Splash] Waiting for auth state changes (max 10s)...`
   - Then: `[Splash] Auth state timeout, using current user`
   - Solution: Check if user is actually signed in, check Firebase Auth
   - Expected: Should see `[Splash] User already signed in: <uid>`

2. **Firestore Not Ready**
   - Look for: `[Splash] Firestore readiness check attempt 1/3`
   - Then: `[Splash] Firestore ready check failed: <error>`
   - Solution: Check Firestore connectivity, check offline persistence
   - Expected: Should see `[Splash] ✅ Firestore is ready`

3. **Routing Failed**
   - Look for: `[Splash] Firestore routing attempt 1/3`
   - Then: `[Splash] Firestore routing attempt 3/3 failed: <error>`
   - Solution: Check if user profile exists in Firestore
   - Expected: Should see `[Splash] ✅ Found <role>`

4. **Offline Fallback Failed**
   - Look for: `[Splash] Using cached profile for routing...`
   - Then: `[Splash] No cached profile found`
   - Solution: User needs to sign in online first to cache profile
   - Expected: Should see `[Splash] ✅ Cached profile is <role>`

---

### Issue: "User routed to wrong home screen"

**Possible Causes:**

1. **Cached Profile Outdated**
   - Look for: `[Splash] Using cached profile for routing`
   - Solution: Clear app cache, sign in again
   - Expected: Should use fresh Firestore data on next sign-in

2. **Multiple User Profiles**
   - Look for: `[Splash] ✅ Found marketplace seller` then `[Splash] ✅ Found org rep`
   - Solution: Check Firestore - user should only exist in one collection
   - Expected: Should find user in only one collection

3. **Firestore Query Failed**
   - Look for: `[Login] Firestore routing attempt X failed: <error>`
   - Solution: Check Firestore connectivity, check user document exists
   - Expected: Should see `[Login] ✅ Found <role>`

---

### Issue: "Sign-in works but routing fails"

**Possible Causes:**

1. **Firestore Timeout**
   - Look for: `[Login] Firestore routing attempt X failed: TimeoutException`
   - Solution: Check network speed, increase timeout if needed
   - Expected: Should retry and succeed

2. **User Profile Missing**
   - Look for: `[Login] Firestore routing attempt 3/3 failed`
   - Then: `[Login] No user profile found, routing to JoinCommunityScreen`
   - Solution: User needs to complete registration
   - Expected: Should see `[Login] ✅ Found <role>`

3. **Offline Cache Missing**
   - Look for: `[Login] No cached profile found`
   - Solution: User needs to sign in online first
   - Expected: Should see `[Login] Using cached profile for routing`

---

## Log Examples

### Successful Sign-In (Online)
```
[AuthService] Sign in attempt 1/3 for user@example.com
[AuthService] ✅ Sign in successful on attempt 1
[Login] Starting sign in for user@example.com
[Login] Sign in successful, routing user...
[Login] Firestore routing attempt 1/3
[Login] ✅ Found community member, routing to CommunityHomeScreen
```

### Successful Sign-In (With Retry)
```
[AuthService] Sign in attempt 1/3 for user@example.com
[AuthService] Sign in Firebase error on attempt 1: network-request-failed
[AuthService] Retrying sign in after 2s...
[AuthService] Sign in attempt 2/3 for user@example.com
[AuthService] ✅ Sign in successful on attempt 2
[Login] Sign in successful, routing user...
[Login] Firestore routing attempt 1/3
[Login] ✅ Found community member, routing to CommunityHomeScreen
```

### Successful Sign-In (Offline Fallback)
```
[Login] Firestore routing attempt 1/3
[Login] Firestore routing attempt 1/3 failed: SocketException
[Login] Firestore routing attempt 2/3 failed: SocketException
[Login] Firestore routing attempt 3/3 failed: SocketException
[Login] Firestore routing failed, trying offline-first routing...
[Login] Using cached profile for routing
[Login] ✅ Cached profile is Community Member, routing to CommunityHomeScreen
```

### Failed Sign-In (Invalid Credentials)
```
[AuthService] Sign in attempt 1/3 for user@example.com
[AuthService] Sign in Firebase error on attempt 1: wrong-password
[AuthService] Not a network error (wrong-password), giving up
[Login] FirebaseAuthException: wrong-password - The password is invalid or the user does not have a password.
```

### Failed Sign-In (Network Error)
```
[AuthService] Sign in attempt 1/3 for user@example.com
[AuthService] Sign in Firebase error on attempt 1: network-request-failed
[AuthService] Retrying sign in after 2s...
[AuthService] Sign in attempt 2/3 for user@example.com
[AuthService] Sign in Firebase error on attempt 2: network-request-failed
[AuthService] Retrying sign in after 2s...
[AuthService] Sign in attempt 3/3 for user@example.com
[AuthService] Sign in Firebase error on attempt 3: network-request-failed
[AuthService] Max retries reached for sign in
[Login] FirebaseAuthException: network-request-failed - A network error (such as timeout, interrupted connection or unreachable host) has occurred.
```

### Successful App Restart (Cached Session)
```
[Splash] Starting auth check...
[Splash] User already signed in: abc123def456
[Splash] Routing user abc123def456...
[Splash] Firestore readiness check attempt 1/3
[Splash] ✅ Firestore is ready
[Splash] Firestore routing attempt 1/3
[Splash] ✅ Found community member
```

---

## Debugging Checklist

When sign-in fails:

- [ ] Check `[AuthService]` logs for retry attempts
- [ ] Check if error is network-related or auth-related
- [ ] Check `[Login]` logs for routing attempts
- [ ] Check if Firestore queries are timing out
- [ ] Check if user profile exists in Firestore
- [ ] Check if offline cache exists in SharedPreferences
- [ ] Check network connectivity
- [ ] Check Firebase configuration
- [ ] Check Firestore rules (if using security rules)
- [ ] Check user document structure in Firestore

---

## Performance Metrics

### Expected Timings

- **Firebase Initialization:** < 5 seconds
- **Firestore Readiness Check:** < 3 seconds
- **Auth State Restoration:** < 10 seconds
- **Firestore Query (online):** < 2 seconds
- **Firestore Query (with retry):** < 10 seconds
- **Total Sign-In Flow:** < 15 seconds

### Slow Performance Indicators

- `[Firebase]` logs taking > 5 seconds
- `[Firestore]` readiness check failing multiple times
- `[Login]` Firestore routing retrying multiple times
- Multiple `[AuthService]` retry attempts

---

## Network Simulation

### Simulate Network Timeout
1. Open Chrome DevTools (if using web)
2. Go to Network tab
3. Set throttling to "Slow 3G"
4. Try sign-in
5. Check logs for retry behavior

### Simulate Offline
1. Disable network in device settings
2. Try sign-in
3. Check logs for offline fallback
4. Enable network
5. Verify sync behavior

### Simulate Firestore Delay
1. Add artificial delay in Firestore queries (for testing)
2. Try sign-in
3. Check logs for timeout and retry behavior

---

## Useful Firebase Console Checks

1. **Check User Exists**
   - Go to Firebase Console → Authentication
   - Search for user email
   - Verify user is enabled

2. **Check User Profile**
   - Go to Firestore → Collections
   - Check `members`, `org_rep`, `marketplace_sellers`
   - Verify user document exists in correct collection

3. **Check Firestore Rules**
   - Go to Firestore → Rules
   - Verify rules allow read/write for authenticated users

4. **Check Offline Persistence**
   - In app, check SharedPreferences
   - Look for `user_profile` key
   - Verify cached data is valid JSON

---

## Common Fixes

### Fix: Clear Cache
```
adb shell pm clear com.example.canopy  # Android
# or
Settings → General → iPhone Storage → Canopy → Offload App → Reinstall  # iOS
```

### Fix: Clear SharedPreferences
```dart
// In code
await UserPersistence.clearUserData();
```

### Fix: Force Firestore Sync
```dart
// In code
await FirebaseFirestore.instance.enableNetwork();
```

### Fix: Reset Auth State
```dart
// In code
await FirebaseAuth.instance.signOut();
```

---

## Support

If issues persist:

1. Collect all logs with `[.*]` filter
2. Check Firebase Console for errors
3. Verify Firestore rules
4. Check network connectivity
5. Try on different device/network
6. Check Firebase quota usage
7. Review Firestore indexes
