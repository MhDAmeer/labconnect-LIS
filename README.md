# LabConnect Admin (Flutter)


## First run

```bash
bash setup.sh          # flutter create (android+ios), patches manifests, pub get
flutter run
```

Another server: `flutter run --dart-define=API_BASE=https://your-server`
(default `https://labconnect.melticetech.com`).

Needs Flutter 3.27+ (Dart 3.6+). Android minSdk is set to 23 by the setup script.
Login does not ask for a lab code. The app omits the optional tenant field by
default so the server can select its configured tenant. If your server
requires an explicit tenant slug, set it at build/run time with
`--dart-define=API_TENANT=your-tenant-slug`.

## What is implemented (guide section → code)

| Guide | Where |
|---|---|
| 2 Envelope, paging (`next`), both error shapes, status handling | `core/network/api_client.dart` |
| 2/4 Single token refresh on 401, rotating refresh token saved, retry once | `ApiClient._send / _doRefresh` |
| 3 Home tiles from `/auth/me/permissions/` (`*`, `ORDERS:` prefix) | `PermissionSet`, `features/home` |
| 4 Login / me / permissions / logout (tokens wiped even if logout fails) | `AuthRepository`, `SessionController` |
| 5 Facilities list + details | `features/facilities` |
| 6 Patients search (paged) + details by MRN + "Orders" button (`patient_id`) | `features/patients` |
| 7 Orders list (status, dates, patient), details, facility time zone display | `features/orders` |
| 8 Results (`group=order`), patient banner, Pending, 2-decimals, PDF view/download | `features/results`, `ReportService` |
| 10 Secure storage, no logging, lock after background, clear on logout | `TokenStorage`, `app.dart`, `main.dart` |

## Notes

* **Helix animation** is drawn live with a `CustomPainter` on the login page only
  (no video file): crisp at 4K, zero download size, honours "reduce motion".
* After 5 minutes in the background the session is closed and Login is shown
  (`AppConfig.backgroundLockAfter`). Saved report PDFs are deleted on logout.
* `next` links are rebuilt on our own base URL so the token can never be sent elsewhere.
* The guide doesn't list the fields inside `insurances`, `next_of_kin`, `test_detail`,
  `physician_detail` etc., so those are read defensively - confirm against the test server.
* Appointments and any create/edit are out of scope, as in the guide.

## Tests
`flutter test`
