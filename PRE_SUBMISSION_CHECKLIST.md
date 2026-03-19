# RediM8 Pre-Submission Checklist

## Release posture

Ship RediM8 1.0 as a preparedness companion for Australian households:
- Official alerts first
- Offline readiness and planning
- Local emergency tools when connectivity fails

Do not position 1.0 as an authoritative emergency network or responder platform.

## Must complete before submission

- [ ] Validate live StoreKit products in TestFlight for `monthly`, `annual`, and `lifetime`
- [ ] Verify restore purchases and Manage Subscription from a fresh install
- [ ] Confirm Emergency Unlock never charges the user and expires cleanly
- [ ] Reconcile App Privacy nutrition labels with actual data flows, especially precise location sent to third-party services
- [ ] Confirm Privacy Policy and Terms of Use URLs are live in App Store Connect and reachable in-app
- [ ] Verify first-launch permission timing on a clean device with no pre-granted permissions
- [ ] Verify Bluetooth, local network, location, camera, and photo-library prompts appear only after user context
- [ ] Confirm release build has no reachable debug, staging, or advanced install surfaces
- [ ] Confirm paywall copy, pricing, and plan durations match live App Store Connect products

## Manual QA matrix

- [ ] Fresh install on iPhone SE-class screen
- [ ] Fresh install on standard iPhone
- [ ] Fresh install on large iPhone
- [ ] If iPad is supported, verify layout and safe areas there too
- [ ] Airplane mode walkthrough for Home, Map, Guides, Vault, and Settings
- [ ] Deny location permission and verify graceful fallback
- [ ] Deny Bluetooth and local network permissions and verify graceful fallback
- [ ] Trigger onboarding completion and relaunch the app
- [ ] Kill and relaunch mid-flow during onboarding, paywall, and map usage
- [ ] Download offline map content, interrupt the flow, relaunch, and verify recovery
- [ ] Unlock vault, preview a document, background the app, and verify lock/cleanup behavior
- [ ] Verify Emergency Mode, Leave Now, Safe Mode, and priority flows from a clean state
- [ ] Verify Home and Settings for Dynamic Type and VoiceOver on key paths

## App Review safety checks

- [ ] Home, Alerts, and Safety surfaces clearly distinguish RediM8 guidance from official agency instructions
- [ ] Community and mesh data remain visibly unverified
- [ ] Mesh/community data do not affect routing unless a future trust model is implemented
- [ ] Free tier remains meaningfully usable without forcing purchase
- [ ] Screenshots and metadata do not imply government affiliation or guaranteed delivery

## Release-candidate cleanup

- [ ] Remove or downgrade noisy release logs that do not help users or support
- [ ] Confirm optional bundled content missing from this build fails softly
- [ ] Confirm large re-downloadable assets are excluded from backup
- [ ] Confirm no sensitive data is logged in release flows
- [ ] Archive a Release build and smoke test that build, not just Debug

## Explicitly defer to 1.1

- Full mesh peer authentication / trust model
- Broader app-wide localization beyond the highest-traffic 1.0 surfaces
- Any expansion of AI capabilities or claims
- Additional map/network features that increase complexity without increasing trust

## Ship decision

Only submit when all items in `Must complete before submission`, `Manual QA matrix`, and `App Review safety checks` are checked off.
