# Haraya Flutter App

A Flutter mobile app for the **Haraya** community marketplace platform, connecting buyers, sellers, and riders.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x (`flutter --version`)
- A running instance of the Flask backend (`app.py`)

### 1. Configure the backend URL

Open `lib/services/api_service.dart` and set your server IP:

```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:5000';
```

> **Android emulator:** use `http://10.0.2.2:5000`  
> **iOS simulator:** use `http://127.0.0.1:5000`  
> **Physical device:** use your machine's local network IP, e.g. `http://192.168.1.x:5000`

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

---

## 📱 Features

| Screen | Description |
|--------|-------------|
| **Splash** | Animated logo with auto session restore |
| **Login** | Sign in with email & password (matches `/login` POST API) |
| **Sign Up** | Create buyer account (fname, lname, email, password) |
| **Home** | Role-aware dashboard (buyer / seller / rider / admin) |
| **Apply as Seller** | Full seller application form with file uploads → `/apply` |
| **Apply as Rider** | Full rider application form with 5 file uploads → `/RiderApply` |

---

## 🎨 Design System

Colors and typography are derived directly from `styles.css`:

| Token | Value | Usage |
|-------|-------|-------|
| `primary` | `#5682B1` | Buttons, links, icons |
| `primaryLight` | `#739EC9` | Hover states, accents |
| `headerBg` | `#FFE8DB` | App bar, splash background |
| `sectionBg` | `#F6F9F6` | Card backgrounds |
| `textDark` | `#222831` | Headings |
| Font | Poppins (Google Fonts) | All text |

---

## 🔗 API Endpoints Used

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/login` (action=signin) | User login |
| `POST` | `/login` (action=signup) | Register new buyer |
| `GET` | `/logout` | Clear session |
| `POST` | `/apply` | Seller application (multipart) |
| `POST` | `/RiderApply` | Rider application (multipart) |

---

## 📋 Android Permissions (add to `AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

For **HTTP** (non-HTTPS) Flask dev server, also add inside `<application>`:

```xml
android:usesCleartextTraffic="true"
```

## 📋 iOS Permissions (add to `Info.plist`)

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Haraya needs access to pick images for your application.</string>
<key>NSCameraUsageDescription</key>
<string>Haraya needs camera access to capture photos.</string>
```

---

## 📁 Project Structure

```
lib/
├── main.dart                    # Entry point + splash
├── theme.dart                   # Colors & ThemeData
├── services/
│   └── api_service.dart         # All HTTP calls to Flask backend
├── models/
│   └── user_model.dart          # User data model
├── widgets/
│   └── haraya_widgets.dart      # Reusable UI components
└── screens/
    ├── login_screen.dart        # Login page
    ├── signup_screen.dart       # Registration page
    ├── home_screen.dart         # Role-aware home dashboard
    ├── seller_apply_screen.dart # Seller application form
    └── rider_apply_screen.dart  # Rider application form
```
