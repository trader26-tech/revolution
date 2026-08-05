# Revolution — Flutter frontend

Feature-based Flutter app that talks to the FastAPI backend.

## Structure

```
lib/
├── main.dart                     App entrypoint (RevolutionApp)
├── core/                         Cross-cutting infrastructure
│   ├── config/app_config.dart    App name + API base URL (dart-define)
│   ├── network/api_client.dart   Thin HTTP client + ApiException
│   ├── theme/app_theme.dart      Light/dark Material 3 themes
│   ├── routing/                  Navigation / routes
│   └── utils/                    Formatters, helpers
├── features/                     One folder per feature
│   └── home/
│       ├── data/                 Repositories (talk to ApiClient)
│       ├── domain/               Models / entities
│       └── presentation/         Widgets / pages / state
└── shared/                       Reused across features
    ├── models/
    └── widgets/
```

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

The default API base URL is `http://localhost:8000`. Override it with
`--dart-define=API_BASE_URL=...` for other environments.
