# 🛡️ ZORO APP - COMPLETE SECURITY & BUG FIX PROMPT
## Master Prompt for AI Assistant to Fix ALL Issues

📌 PROJECT CONTEXT
Project: Zoro App (Zero Social Audio App)
Repository: https://github.com/MIDO12A/zoro-app
Type: Social Audio Application (Voice Rooms + Gifts + CP System)
Tech Stack:
Frontend: Flutter (Dart)
Backend: Node.js + Firebase (Firestore, Auth, Storage)
Admin Dashboard: React + TypeScript
Audio Engine: Zego Express Engine
Hosting: Vercel, Railway, Fly.io
Key Systems:
Voice Rooms with real-time audio
Gift System (SVGA/VAP animations)
Lucky Gifts (Gambling mechanics)
CP (Couple) Relationship System
VIP & Level System
Agency System for Hosts
Daily Sign-in Rewards
Self-Update System
WebView Integration
Multi-platform (Android, iOS, Web, Desktop)

🎯 YOUR MISSION
You are a Senior Security Engineer + Flutter Expert + Backend Architect. Your mission is to:
Analyze the entire codebase systematically
Identify ALL security vulnerabilities, bugs, and performance issues
Fix every single issue completely
Test all changes thoroughly
Deploy safely with rollback plan
Document everything clearly

Success Criteria: Zero security vulnerabilities, zero critical bugs, optimal performance.

🔴 CATEGORY 1: CRITICAL SECURITY VULNERABILITIES (Must Fix First)

VULNERABILITY 1.1: Firestore Security Rules - Balance Manipulation
Severity: 🔴 CRITICAL
Location: firestore.rules
Problem: Current rules may allow users to directly modify sensitive fields like coins, diamonds, total_spent, vip_expiry from the client app.
Impact: Users can give themselves unlimited currency, breaking the entire economy.
Requirements:
Implement strict security rules that prevent ANY direct modification of financial fields
Only allow modifications through verified backend transactions
Admin users must be the only ones who can modify certain fields
Use helper functions for authentication and authorization checks
Test that users cannot bypass rules through any means
Verification: Attempt to modify coins field directly from client - must fail with permission denied.

VULNERABILITY 1.2: Identity Spoofing
Severity: 🔴 CRITICAL
Location: All service files that accept userId parameter
Problem: Functions accept userId as parameter from UI, allowing users to send requests on behalf of other users.
Impact: Complete account takeover, unauthorized actions.
Requirements:
Remove all userId parameters from public functions
Always use FirebaseAuth.instance.currentUser!.uid internally
Validate that the authenticated user matches the intended action
Add audit logging for all sensitive operations
Verification: Try to perform action as different user - must fail.

VULNERABILITY 1.3: Gift Sending Race Condition (Double Spending)
Severity: 🔴 CRITICAL
Location: lib/services/firebase_service.dart, gift sending functions
Problem: Rapid double-tap on gift send button can deduct coins twice or cause inconsistent state.
Impact: Financial loss, accounting errors, user complaints.
Requirements:
ALL financial operations MUST use Firestore runTransaction
Verify balance inside transaction before deduction
Implement UI debouncing (disable button after click)
Add optimistic UI with rollback on failure
Create transaction logs for audit
Verification: Send gift rapidly 10 times - should only succeed once if balance allows.

VULNERABILITY 1.4: Hardcoded API Secrets
Severity: 🔴 CRITICAL
Location: lib/services/cloudinary_service.dart, potentially other services
Problem: API keys and secrets hardcoded in source code visible to anyone who decompiles the app.
Impact: Unauthorized access to third-party services, financial loss.
Requirements:
Search entire codebase for hardcoded strings containing "key", "secret", "token", "password"
Replace all with environment variables using --dart-define
Add .env to .gitignore
Document build process with required environment variables
Rotate all exposed secrets immediately
Verification: Run grep -r "secret\|key\|token" lib/ - should find no hardcoded values.

VULNERABILITY 1.5: Client-Side Lucky Gift Logic
Severity: 🔴 CRITICAL
Location: Lucky gift calculation functions
Problem: Win/loss probability calculation happens on client device.
Impact: Users can modify app to always win, causing massive financial loss.
Requirements:
Move ALL probability calculations to backend Cloud Functions
Client sends request, server decides result
Server deducts coins and adds prize atomically
Client only receives result and displays animation
Log all lucky gift attempts for audit
Verification: Modify client code to always win - must have no effect.

VULNERABILITY 1.6: Private Room Password Bypass
Severity: 🔴 CRITICAL
Location: Room joining functions
Problem: Users may bypass password protection on private rooms.
Impact: Unauthorized access to private conversations.
Requirements:
Verify password on server before allowing entry
Never send password to client in room data
Use secure comparison (timing-safe)
Log failed password attempts
Implement lockout after multiple failures
Verification: Try to join password-protected room without password - must fail.

VULNERABILITY 1.7: Unauthorized Recording Detection
Severity: 🔴 CRITICAL
Location: Room recording features
Problem: Users can record conversations without others' knowledge.
Impact: Privacy violation, legal liability.
Requirements:
Add visible indicator when recording is active
Notify all participants when recording starts
Require room owner permission for recording
Log all recording sessions
Add rules preventing unauthorized recording flags
Verification: Start recording - all participants must see notification.

VULNERABILITY 1.8: Gift Price Manipulation
Severity: 🔴 CRITICAL
Location: Gift sending functions
Problem: Gift price sent from client can be modified to pay less.
Impact: Users get expensive gifts for cheap.
Requirements:
Never trust price from client
Always fetch price from server using gift ID
Verify price matches before processing
Log price mismatches as security events
Verification: Modify client to send gift with price 0 - must fail.

🟠 CATEGORY 2: HIGH SEVERITY SECURITY ISSUES

VULNERABILITY 2.1: Malicious File Upload
Severity: 🟠 HIGH
Location: File upload functions (Cloudinary, Firebase Storage)
Problem: Users can upload executable files or scripts instead of images.
Impact: Malware distribution, XSS attacks.
Requirements:
Validate file extension whitelist (jpg, png, gif, webp, mp4 only)
Check MIME type matches extension
Limit file size (e.g., 10MB max)
Scan files for malicious content
Store files with random names, not user-provided names
Verification: Try to upload .exe file - must be rejected.

VULNERABILITY 2.2: XSS in Chat Messages
Severity: 🟠 HIGH
Location: Chat message display functions
Problem: Malicious HTML/JavaScript in chat messages can execute.
Impact: Account theft, session hijacking.
Requirements:
Sanitize all user input before display
Use html package to strip dangerous tags
Escape special characters
Never use Raw HTML rendering
Implement Content Security Policy
Verification: Send message with <script>alert('xss')</script> - must display as text, not execute.

VULNERABILITY 2.3: CP Relationship Manipulation
Severity: 🟠 HIGH
Location: lib/features/cp/cp_service.dart
Problem: Users can create relationships with themselves, deleted users, or bypass limits.
Impact: Data corruption, logic errors.
Requirements:
Prevent self-relationships
Verify both users exist and are active
Check neither user already has a CP partner
Use transactions for atomic updates
Validate on both client and server
Verification: Try to create CP with self - must fail.

VULNERABILITY 2.4: VIP Extension Bypass
Severity: 🟠 HIGH
Location: VIP purchase functions
Problem: Users can extend VIP status without payment.
Impact: Revenue loss.
Requirements:
Only allow VIP modification through verified payment flow
Use Firestore rules to prevent direct field modification
Verify payment receipt on server before granting VIP
Log all VIP changes
Verification: Try to set vip_expiry directly - must fail.

VULNERABILITY 2.5: Push Notification Spoofing
Severity: 🟠 HIGH
Location: Notification sending functions
Problem: Users can send fake system notifications.
Impact: Phishing, misinformation.
Requirements:
Only allow notifications from Cloud Functions
Verify notification source
Add authentication for notification API
Log all notification sends
Verification: Try to send notification from client - must fail.

VULNERABILITY 2.6: Agency Host Verification Bypass
Severity: 🟠 HIGH
Location: lib/features/host_agency/agency_service.dart
Problem: Unverified users can join agencies and receive gifts.
Impact: Fraud, revenue loss.
Requirements:
Re-implement verification check
Only isVerifiedHost: true users can join
Admin must approve through dashboard
Use transactions for atomic updates
Verification: Unverified user tries to join agency - must fail.

VULNERABILITY 2.7: Agency Commission Calculation Errors
Severity: 🟠 HIGH
Location: lib/services/agency_target_evaluator.dart
Problem: Complex formulas with calculation errors.
Impact: Incorrect payouts, disputes.
Requirements:
Simplify commission logic
Move calculations to backend
Use atomic operations
Create audit logs
Implement reconciliation jobs
Verification: Calculate commission manually - must match system.

VULNERABILITY 2.8: Data Source Split Brain
Severity: 🟠 HIGH
Location: lib/features/signin/signin_service.dart, admin dashboard
Problem: App reads Firestore, admin writes Supabase (or vice versa).
Impact: Inconsistent data, admin changes not reflected.
Requirements:
Unify all data sources to Firestore
Remove Supabase dependencies completely
Or implement proper sync mechanism
Test all admin operations reflect in app
Verification: Change setting in admin - must appear in app immediately.

🟡 CATEGORY 3: MEDIUM SEVERITY SECURITY ISSUES

VULNERABILITY 3.1: Self-Update Signature Verification
Severity: 🟡 MEDIUM
Location: lib/services/update_service.dart
Problem: APK updates not verified, allowing malicious updates.
Impact: Malware installation.
Requirements:
Verify SHA256 checksum before installation
Compare with expected hash from server
Only accept updates from official source
Show verification status to user
Verification: Try to install modified APK - must be rejected.

VULNERABILITY 3.2: WebView JavaScript Injection
Severity: 🟡 MEDIUM
Location: WebView screens
Problem: JavaScript enabled in WebView allows code execution.
Impact: Data theft, session hijacking.
Requirements:
Disable JavaScript unless absolutely necessary
Use JavascriptMode.restricted if needed
Never expose sensitive data to WebView
Implement message passing securely
Verification: Try to access localStorage from WebView - must fail.

VULNERABILITY 3.3: Unencrypted Local Storage
Severity: 🟡 MEDIUM
Location: SharedPreferences usage
Problem: Sensitive data stored unencrypted.
Impact: Data theft if device compromised.
Requirements:
Use flutter_secure_storage for sensitive data
Encrypt tokens, passwords, keys
Never store secrets in plain SharedPreferences
Clear sensitive data on logout
Verification: Root device and check storage - secrets must be encrypted.

VULNERABILITY 3.4: HTTP Instead of HTTPS
Severity: 🟡 MEDIUM
Location: All network requests
Problem: Some connections use HTTP instead of HTTPS.
Impact: Man-in-the-middle attacks, data interception.
Requirements:
Enforce HTTPS for all connections
Add ATS (App Transport Security) on iOS
Add network security config on Android
Reject HTTP connections
Verification: Try HTTP connection - must be rejected.

VULNERABILITY 3.5: Missing Certificate Pinning
Severity: 🟡 MEDIUM
Location: Network layer (Dio, HttpClient)
Problem: No certificate pinning allows MITM attacks.
Impact: Data interception, credential theft.
Requirements:
Implement certificate pinning in Dio
Pin to server certificate SHA256
Handle certificate rotation
Add fallback for emergencies
Verification: Use proxy with custom cert - must fail.

VULNERABILITY 3.6: Spam and Flood Attacks
Severity: 🟡 MEDIUM
Location: All user-facing APIs
Problem: No rate limiting allows spam.
Impact: Service degradation, abuse.
Requirements:
Implement rate limiting per user
Limit messages per minute
Limit gift sends per minute
Limit room creation
Add cooldown periods
Verification: Send 100 messages in 1 second - must be throttled.

🟢 CATEGORY 4: PERFORMANCE & STABILITY ISSUES

ISSUE 4.1: Background Animation Consumption
Severity: 🟢 PERFORMANCE
Location: lib/screens/room/room_screen.dart
Problem: SVGA/VAP animations run in background.
Impact: Battery drain, memory leaks, crashes.
Requirements:
Implement WidgetsBindingObserver
Pause all animations when app backgrounded
Resume when foregrounded
Dispose players properly
Monitor memory usage
Verification: Background app for 1 hour - battery usage must be minimal.

ISSUE 4.2: Unoptimized Image Loading
Severity: 🟢 PERFORMANCE
Location: All image displays
Problem: Large images loaded without constraints.
Impact: High memory, slow loading, crashes.
Requirements:
Use CachedNetworkImage with size constraints
Set memCacheWidth and memCacheHeight
Implement proper error handling
Add placeholder widgets
Clear cache periodically
Verification: Load 100 images - memory must stay under 200MB.

ISSUE 4.3: Room State Synchronization
Severity: 🟢 STABILITY
Location: Room screen, seat management
Problem: Delayed Firestore updates cause inconsistent state.
Impact: Two users on same seat, confusion.
Requirements:
Use StreamBuilder for real-time updates
Implement optimistic UI with rollback
Add visual indicators for pending operations
Handle conflicts gracefully
Verification: Two users try same seat - only one succeeds.

ISSUE 4.4: Missing Audio Permissions
Severity: 🟢 STABILITY
Location: App initialization, room entry
Problem: Permissions not requested properly.
Impact: Audio features don't work.
Requirements:
Request permissions before room entry
Use permission_handler properly
Show clear error messages if denied
Provide instructions to enable in settings
Verification: Fresh install - must request permissions before room.

ISSUE 4.5: Agency Member Count Sync
Severity: 🟢 STABILITY
Location: Agency join/leave functions
Problem: Member count becomes inaccurate.
Impact: Wrong statistics, commission errors.
Requirements:
Use FieldValue.increment() for atomic updates
Implement reconciliation jobs
Add periodic audits
Log all changes
Verification: 10 users join/leave rapidly - count must be accurate.

ISSUE 4.6: Zego Engine Lifecycle Issues
Severity: 🟢 STABILITY
Location: lib/services/room_audio_service.dart
Problem: Double engine initialization causes crashes (SIGSEGV).
Impact: App crashes, poor experience.
Requirements:
Serialize engine init/dispose
Prevent double initialization
Handle errors gracefully
Keep seat on minimize
Proper cleanup on exit
Verification: Enter/exit room 10 times rapidly - no crashes.

📋 EXECUTION PLAN
Phase 1: Preparation (Day 1)
Create complete backup of current state
Document current behavior of all systems
Set up testing environment
Create branch for fixes

Phase 2: Critical Security Fixes (Days 2-4)
Fix Firestore security rules
Implement identity verification everywhere
Add transaction-based financial operations
Remove all hardcoded secrets
Move lucky gift logic to server
Fix private room security
Add recording notifications
Fix gift price verification

Phase 3: High Severity Fixes (Days 5-7)
Implement file upload validation
Add XSS protection
Fix CP relationship logic
Secure VIP extension
Fix notification system
Re-implement host verification
Fix commission calculations
Unify data sources

Phase 4: Medium Severity Fixes (Days 8-10)
Add update signature verification
Secure WebView
Implement encrypted storage
Enforce HTTPS
Add certificate pinning
Implement rate limiting

Phase 5: Performance Fixes (Days 11-13)
Fix background animations
Optimize image loading
Improve room sync
Fix permission handling
Fix agency member count
Fix Zego engine lifecycle

Phase 6: Testing (Days 14-16)
Write unit tests for all critical functions
Write integration tests for workflows
Perform security penetration testing
Test on multiple devices
Load testing for rate limits
Memory leak detection

Phase 7: Deployment (Day 17)
Deploy Firestore rules
Deploy Cloud Functions
Build and test Flutter app
Deploy admin dashboard
Monitor for issues
Create rollback plan

Phase 8: Documentation (Day 18)
Document all changes
Update security policy
Create user guide
Train support team
Create monitoring dashboards

✅ VERIFICATION CHECKLIST
Security Verification
Users cannot modify their own coins/diamonds
All financial operations use transactions
No hardcoded secrets in codebase
Lucky gift logic runs on server only
Firestore rules properly restrict access
Identity spoofing impossible
Private rooms secure
Recording notifications work
Gift prices verified on server
File uploads validated
XSS prevented
CP relationships validated
VIP extension secure
Notifications from server only
Host verification enforced
Commission calculations accurate
Data sources unified
Update signatures verified
WebView secured
Local storage encrypted
HTTPS enforced
Certificate pinning active
Rate limiting working

Performance Verification
Animations pause in background
Images load efficiently
Room state syncs in real-time
Permissions requested properly
Agency counts accurate
Zego engine stable
No memory leaks
Battery usage optimized
Fast loading times
Smooth animations

Business Logic Verification
Only verified hosts join agencies
Commission calculations accurate
Admin changes reflect immediately
Member counts always accurate
All data from single source
Lucky gifts fair and secure
CP relationships valid
VIP system working
Levels calculating correctly
Sign-in rewards accurate

Code Quality Verification
No compilation errors
All tests passing
Code follows best practices
Proper error handling
Clear documentation
No code duplication
Proper separation of concerns
Maintainable architecture

📝 DELIVERABLES
After completing all tasks, provide:
Modified Files List - All files changed with descriptions
Security Audit Report - Detailed security improvements
Performance Metrics - Before/after comparison
Test Results - All test outcomes with evidence
Deployment Guide - Step-by-step instructions
Rollback Plan - How to revert if issues occur
Monitoring Plan - How to detect future issues
Documentation - Updated guides and policies

🚨 CRITICAL CONSTRAINTS
MUST DO:
Create backups before every major change
Test every change thoroughly
Document all modifications
Follow existing code style
Maintain backward compatibility
Use atomic operations for financial data
Log all security-relevant events
Implement defense in depth
MUST NOT:
Break existing functionality
Remove features without replacement
Commit secrets to version control
Make changes without testing
Skip security fixes for convenience
Trust client-side data
Use deprecated APIs
Ignore error handling

🎯 SUCCESS METRICS
The task is successful when:
✅ Zero critical security vulnerabilities
✅ Zero high severity security issues
✅ All medium issues resolved
✅ All performance issues optimized
✅ All tests passing (unit, integration, security)
✅ App builds successfully on all platforms
✅ No regression in existing features
✅ Documentation complete and accurate
✅ Monitoring in place
✅ Rollback plan tested

📞 COMMUNICATION PROTOCOL
If you encounter issues:
STOP immediately
DOCUMENT the problem in detail
ANALYZE root cause
PROPOSE alternative solutions
REQUEST guidance before proceeding
NEVER proceed with uncertain fixes

🚀 EXECUTION COMMAND
BEGIN NOW.
Start with Phase 1 (Preparation) and work through each phase systematically. Report progress after each phase completion. Provide evidence of fixes (test results, screenshots, logs).
Remember: Security is not optional. Every vulnerability must be fixed completely. No shortcuts. No compromises.
Good luck! Make Zoro App the most secure social audio app! 🛡️🚀