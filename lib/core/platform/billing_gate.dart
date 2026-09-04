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
///   • iOS AND Android native → external purchase / portal CTAs
///     hidden, replaced with a neutral informational notice. Existing
///     account access and entitlement state remain visible; both
///     stores allow an organisation to use what it already bought.
///   • Web / Desktop → unchanged. Neither store's payments policy
///     governs them.
///
/// Operational doctrine
/// --------------------
///   Orchestrate is operational infrastructure, not a consumer-
///   content app. The iOS surface must not function as a sales
///   funnel: no upgrade CTAs, no browser redirects to payment,
///   no "buy plan" language. Existing operational access after
///   login is fine; selling subscriptions on iOS is not.
///
/// Native purchase — LANDED
/// ------------------------
///   StoreKit and Google Play Billing are now wired, so the gate has
///   inverted exactly where it said it would: in a store build the app
///   MAY take a payment, through the store, in app. What stays
///   forbidden is unchanged — no link out to Stripe, no browser
///   redirect to a checkout, no "manage billing on our website".
///
///   Two questions, deliberately kept apart, because conflating them
///   is what produced a build that could sell nothing at all:
///     externalPurchaseAllowed — may we send someone OUT to pay?
///     inAppPurchaseAllowed    — may we take a payment HERE?
///   On web and desktop the first is true and the second is false. In
///   a store build it is the other way round. Neither platform has
///   both, and no platform has neither.

/// True when the running app is the iOS native binary (not the web
/// build served from iOS Safari). Uses `kIsWeb` first so an iPad
/// loading the web build is treated as web, not iOS — `defaultTarget`
/// reports iOS for both native and Safari otherwise.
bool get isIosAppStorePlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// True when the running app is the Android native binary — a Play
/// build, not Chrome on a phone.
bool get isPlayStorePlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// True when the running app was installed from an app store, either
/// one.
///
/// This gate covered iOS only, which was a live Play exposure rather
/// than an oversight of taste. Google's Payments policy prohibits
/// directing users to external payment methods "via app listings,
/// promotions, webviews, buttons, links, or sign-up flows" — the same
/// prohibition Apple applies, arriving from a different rule. An
/// Android build showing a Stripe checkout CTA would have breached it
/// while the iOS build beside it was careful.
///
/// Verified against first-party policy on 2026-09-04:
///   Apple, App Review Guidelines 3.1.3(c) Enterprise Services and
///   3.1.3(f) Free Stand-alone Apps — an app sold directly to
///   organisations for their employees may let those users access a
///   previously-purchased subscription, "provided there is no
///   purchasing inside the app, or calls to action for purchase
///   outside of the app".
///   Google, Understanding Google Play's Payments policy — apps that
///   are "consumption only ... do not enable users to purchase access
///   to digital goods or services from within the app" may let a user
///   "log in when the app opens and access content paid for somewhere
///   else", and developers "may inform users about external purchasing
///   without direct links".
///
/// Both permit exactly what Orchestrate does: entitlement acquired by
/// the organisation elsewhere, recognised on the device. Neither
/// permits a link out to buy it.
bool get isAppStorePlatform => isIosAppStorePlatform || isPlayStorePlatform;

/// True when the platform allows in-app prompts that route to an
/// external purchase or subscription-management flow. False in both
/// store binaries; true on web and desktop, which are not governed by
/// either store's payments policy.
bool get externalPurchaseAllowed => !isAppStorePlatform;

/// True when a payment may be taken inside the app, through the store
/// that shipped it.
///
/// This is the permitted half of both policies rather than an
/// exemption from them: Apple requires digital subscriptions to be
/// sold through in-app purchase, and Google requires the same through
/// Play Billing. Selling here is not tolerated, it is the rule.
///
/// False on web and desktop — not for policy reasons but because
/// there is no store underneath them. Those rails are billed
/// directly, and an organisation that bought on one is recognised on
/// all of them, because entitlement belongs to the organisation and
/// not to the device that paid.
bool get inAppPurchaseAllowed => isAppStorePlatform;

/// Neutral copy shown where an EXTERNAL purchase or management CTA
/// would otherwise sit in a store build.
///
/// Still correct, and still needed: the store sells the subscription,
/// but it does not sell everything, and a person looking for an
/// invoice or a contract change is asking about something no store
/// handles. This is what they are told instead of a link.
///
/// It is no longer the answer to "how do I subscribe?" — in a store
/// build that question now has a button. Intentionally passive
/// — it informs, and it does not link, instruct, or funnel. That is the
/// narrow thing both policies allow: Apple forbids "calls to action for
/// purchase outside of the app", and Google permits informing "without
/// direct links".
const String kStorePlanManagementNotice =
    'Plan management is handled with your organisation directly.';

/// Retained under its old name so existing call sites keep compiling.
/// Prefer [kStorePlanManagementNotice]; the wording is no longer
/// iOS-specific because the rule is no longer iOS-only.
const String kIosPlanManagementNotice = kStorePlanManagementNotice;
