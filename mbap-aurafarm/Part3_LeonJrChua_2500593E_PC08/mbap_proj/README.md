# AuraFarm

Mobile app for CIT2C18 Mobile App Development, AY2026/27 April Semester, Part 3.

Leon Jr Chua · 2500593E · PC08

## What it does

AuraFarm turns two photos into a shareable "vibe card". The user picks an
outfit photo and a selfie, an AI reads the facial expression and the outfit,
and it generates a mood label, an aura line, a song match and a meme match.
The finished card is composed on screen, flattened to an image and posted to
a social feed.

## Running it

```
flutter pub get
flutter run -d chrome        # web
flutter run                  # android emulator
```

The Gemini API key is set in `lib/services/ai_service.dart`. It can also be
supplied at run time:

```
flutter run --dart-define=GEMINI_API_KEY=your_key
```

## Firebase setup

The app uses Firebase Authentication and Cloud Firestore.

1. Publish `firestore.rules`
2. Create the composite indexes in `firestore.indexes.json`
3. Sign in and create cards through the app; the demo records already in the
   `posts` collection were made this way

## Project structure

```
lib/
  models/      VibeCard, AppUser, AiVibeResult, CardLayout
  services/    firestore, user, ai, music, export, biometric, preview player
  providers/   riverpod providers for each service and query
  screens/     13 screens (auth, feed, create, editor, detail, profile, settings)
  widgets/     reusable card, canvas, like button, banners
  utils/       meme library, sample comments, photo cache
  theme/       AuraTheme palettes (5)
```

## Part 3 features

- CRUD on the `posts` collection: insert, select all, select one, update, delete
- Advanced queries: single filter, same-field range, multi-field filter,
  sort order, `whereIn`, and count/sum/average aggregation
- Applied AI: Gemini multimodal image analysis returning structured JSON
- Additional features: vibe card export to image, offline detection and
  handling, biometric lock, music integration (iTunes artwork + previews)
- Personalisation: custom app icon, splash screen, four selectable Aura
  palettes persisted per account

## Notes

Photos are stored as base64 inside the Firestore document because Firebase
Storage requires a paid plan. Images are compressed and the capture is
bounded so a document stays well under the 1 MiB limit.
