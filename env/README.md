# Environments

PilotEnRoute builds for three environments. Configuration is supplied at build
time with `--dart-define-from-file`; nothing is read from the filesystem at
runtime, so a shipped binary contains exactly the values it was built with.

| | dev | staging | prod |
|---|---|---|---|
| `APP_ENV` | `dev` | `staging` | `prod` |
| applicationId | `com.americangroup.pilotenroute.dev` | `….bodyquest.staging` | `com.americangroup.pilotenroute` |
| Launcher name | PilotEnRoute Dev | PilotEnRoute Staging | PilotEnRoute |
| versionName suffix | `-dev` | `-staging` | *(none)* |

All three install side by side, so a tester can hold every build at once and a
staging install can never overwrite production.

## Files

| File | Committed? | Contents |
|---|---|---|
| `env/dev.json` · `env/staging.json` · `env/prod.json` | yes | Non-secret configuration |
| `env/secrets.example.json` | yes | Template for QA credentials |
| `env/secrets.json` | **no** — gitignored | Real QA credentials, internal builds only |

Committing configuration is deliberate. The Supabase **anon/publishable** key is
designed to be public — it grants only what Row Level Security allows, and it
ships inside the APK regardless. Genuine secrets (the service-role key, signing
keys, QA passwords) never appear in any file here.

## Variables

| Key | Meaning |
|---|---|
| `APP_ENV` | Selects the environment. Defaults to `prod` when the flag is omitted, so a forgotten flag fails closed. |
| `SUPABASE_URL` | Backend project URL. Must be `https://`. |
| `SUPABASE_ANON_KEY` | Publishable key. Public by design; protected by RLS. |
| `PRIVACY_URL` · `TERMS_URL` · `SUPPORT_URL` | Legal and support links. Play requires the privacy URL to resolve. |
| `APP_STORE_URL` · `PLAY_STORE_URL` | "Rate app" targets. |
| `GOOGLE_SERVER_CLIENT_ID` · `GOOGLE_IOS_CLIENT_ID` | Public OAuth client ids for native sign-in. Optional; empty disables native Google sign-in. |
| `QA_EMAIL` · `QA_PASSWORD` · `DEV_EMAIL` · `DEV_PASSWORD` · `ADMIN_EMAIL` · `ADMIN_PASSWORD` | **Secrets.** From `env/secrets.json` only. Absent by default, which makes the whole test-account path inert — the "Use test account" button and the credential hint card are not rendered at all. |

## Commands

Run:

```bash
flutter run --flavor dev     --dart-define-from-file=env/dev.json
flutter run --flavor staging --dart-define-from-file=env/staging.json
flutter run --flavor prod    --dart-define-from-file=env/prod.json
```

Internal build that needs the QA shortcut — never for production:

```bash
flutter run --flavor dev \
  --dart-define-from-file=env/dev.json \
  --dart-define-from-file=env/secrets.json
```

Release artifacts:

```bash
flutter build apk       --release --flavor staging --dart-define-from-file=env/staging.json
flutter build appbundle --release --flavor prod    --dart-define-from-file=env/prod.json
```

A production App Bundle additionally needs `android/key.properties`. Without it
the build falls back to the debug keystore and the Play Console will reject the
artifact.

## Guards against shipping the wrong configuration

1. **Fails closed.** `APP_ENV` defaults to `prod`, so a build that forgets the
   flag does not silently become a dev build pointed at dev infrastructure.
2. **Startup check.** `AppEnv.validate()` runs in `main()` before any UI and
   reports an empty/non-https backend URL, or QA credentials present in a
   production release. It throws in debug/profile so a developer hits it
   immediately; in release it only logs.
3. **Build-time check.** `test/app_env_test.dart` is the real gate: it validates
   every committed `env/*.json`, asserts prod points at the production listing,
   asserts no committed file carries credentials, fails if the code reads a
   `fromEnvironment` key that is not documented here, and fails if any source
   file reintroduces a literal test password. It runs in CI.
