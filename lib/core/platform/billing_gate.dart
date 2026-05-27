import 'package:flutter/foundation.dart';

/// Platform-aware billing gate for App Store §3.1.1 compliance.
///
/// Apple disallows in-app prompts that direct users to external
/// purchase or subscription flows for digital functionality. The
/// gate centralizes that policy in one place so every billing
/// surface in the app — pricing, subscribe, billing portal, account,
/// continuity — reads the same flag.
///
/// Rule
/// ----
///   • iOS native → external purchase / portal CTAs hidden, replaced
///     with a neutral informational notice. Existing account access
///     and subscription state remain visible (Apple allows existing
///     customer access).
///   • Web / Android / Desktop → unchanged. The existing Stripe
///     checkout + billing portal flow continues as today.
///
/// Operational doctrine
/// --------------------
///   Orchestrate is operational infrastructure, not a consumer-
///   content app. The iOS surface must not function as a sales
///   funnel: no upgrade CTAs, no browser redirects to payment,
///   no "buy plan" language. Existing operational access after
///   login is fine; selling subscriptions on iOS is not.
///
/// Future IAP
/// ----------
///   When StoreKit / Google Play Billing is introduced, the gate
///   inverts (purchase allowed in-app on iOS) without forcing every
///   call site to change shape. Until that work lands, this file is
///   the single source of truth.

/// True when the running app is the iOS native binary (not the web
/// build served from iOS Safari). Uses `kIsWeb` first so an iPad
/// loading the web build is treated as web, not iOS — `defaultTarget`
/// reports iOS for both native and Safari otherwise.
bool get isIosAppStorePlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// True when the platform allows in-app prompts that route to an
/// external purchase or subscription management flow. False on iOS
/// native; true everywhere else.
bool get externalPurchaseAllowed => !isIosAppStorePlatform;

/// Neutral copy shown in place of any external purchase or
/// subscription-management CTA on iOS. The string is intentionally
/// passive — no link, no funnel, no instruction to leave the app.
/// Apple-review-safe phrasing.
const String kIosPlanManagementNotice =
    'Plan management is currently available via the web platform.';
