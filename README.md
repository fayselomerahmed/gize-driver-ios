# Gize Driver

Gize Driver is the driver-side SwiftUI prototype in a two-app ride-sharing learning project. It explores availability, incoming ride offers, pickup and trip progress, passenger contact, and driver trip history.

> This is a portfolio prototype, not a production ride service. It has no verified production backend, Firebase security rules, payment system, or end-to-end passenger/driver release validation. Do not use it for real rides or real passenger data.

## What it demonstrates

- SwiftUI screens and view models for availability, trip offers, pickup, trip progress, and history.
- MapKit and Core Location for driver map and trip-location workflows.
- Firebase Authentication, Firestore, Realtime Database, and Firebase Messaging integration points.
- Trip-state handling for acceptance, arrival, active rides, cancellation, and completion.
- A shared payload builder for live trip data instead of hard-coded demo identities, stale estimates, and timestamps.

## How the code is organized

| Area | Responsibility |
| --- | --- |
| Core/Authentication | Sign-in and registration UI and state |
| Core/Home | Driver availability, map, and trip coordination |
| Trips/Drivers | Driver-facing offer, pickup, and trip screens |
| Trips/Passengers | Passenger trip-state screens included in this prototype |
| Trips/ViewModel and Models | Trip records, states, user records, and trip coordination |
| Services / Managers | Firebase access, location, and supporting integration code |

The driver app models the person accepting a trip. A separate [Gize Rider app](https://github.com/fayselomerahmed/gize-rider-ios) models the passenger requesting it. The code contains Firebase integration experiments, but a secure shared backend contract and live end-to-end behavior have not been verified.

## Run locally

1. Install Xcode and CocoaPods.
2. In this directory, run pod install.
3. Add your own Firebase iOS configuration as GizeTransport/GoogleService-Info.plist (ignored by Git).
4. Configure a unique bundle identifier and your own signing team in Xcode.
5. Open GizeDriver.xcworkspace and run the GizeDriver scheme on a simulator.

Never add service-account keys, FCM server credentials, signing files, real user records, or production location data to this repository. A Firebase client configuration is not a substitute for restrictive server-side Firebase rules.

## Privacy and security boundaries

- Driver location is sensitive. Request it only when the driver workflow needs it, explain the purpose, honor denied/restricted permission states, and stop publishing availability/location when the driver goes offline.
- Keep passenger/driver identity, phone numbers, device tokens, precise coordinates, and trip documents out of logs and source fixtures.
- Notification delivery must go through a trusted authenticated backend. Legacy FCM server-key calls are disabled unless a server key is configured; never configure that privileged key in the iOS app.
- Before connecting a Firebase project, define and test Authentication, Firestore, and Realtime Database access rules. This repository does not include or verify those rules.
- Creating unregistered passenger records is disabled until a trusted backend can validate consent, identity, and authorization.
- See [SECURITY.md](SECURITY.md) before reporting a security concern.

## Validation status

The source was reviewed for embedded credentials and personal sample data. Debug output that could expose user/trip details, coordinates, or notification tokens was removed or redacted. A fabricated default San Francisco location was removed; the app now reports unavailable location instead of creating a passenger record at an unrelated location. The app has **not** had a complete Xcode simulator build or passenger-to-driver integration test in this environment. No claim of production readiness is made.

## Attribution

Some files retain UberSwiftUI/tutorial author headers. Those attributions remain in place; this project does not claim all source code or artwork is original. Third-party names, marks, and assets belong to their respective owners. No open-source redistribution license is granted by this portfolio publication.
