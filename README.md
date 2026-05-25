# ☕ Dubai Coffee POS — Flutter Mobile App

A full-featured Point-of-Sale mobile application built with **Flutter + Firebase**, converted from the Dubai Coffee web POS system. Supports Android and iOS.

---

## 📁 Project Structure

```
dubai_coffee_pos/
├── lib/
│   ├── main.dart                         # App entry point + routing
│   ├── firebase_options.dart             # Firebase config (auto-generated)
│   │
│   ├── theme/
│   │   └── app_theme.dart                # Colors, typography, Material theme
│   │
│   ├── models/
│   │   └── models.dart                   # AppUser, MenuItem, Order, InventoryItem, etc.
│   │
│   ├── services/
│   │   ├── auth_service.dart             # Firebase Auth CRUD
│   │   ├── auth_provider.dart            # Auth state (ChangeNotifier)
│   │   ├── pos_provider.dart             # POS cart state (ChangeNotifier)
│   │   ├── order_service.dart            # Firestore orders CRUD
│   │   ├── menu_service.dart             # Firestore menu items CRUD
│   │   └── inventory_service.dart        # Firestore inventory CRUD
│   │
│   ├── widgets/
│   │   └── shared_widgets.dart           # Reusable UI components
│   │
│   └── screens/
│       ├── main_shell.dart               # Bottom nav shell
│       ├── auth/
│       │   ├── login_screen.dart         # Sign-in screen
│       │   └── register_screen.dart      # Sign-up screen
│       ├── pos/
│       │   ├── pos_screen.dart           # Menu grid + search + categories
│       │   ├── customer_name_sheet.dart  # Customer name bottom sheet
│       │   ├── cart_sheet.dart           # Order review + discount + payment
│       │   └── receipt_sheet.dart        # Digital receipt
│       ├── history/
│       │   └── history_screen.dart       # Order history + void
│       ├── kitchen/
│       │   └── kitchen_screen.dart       # KDS (Kitchen Display System)
│       ├── reports/
│       │   └── reports_screen.dart       # Sales analytics + charts
│       ├── inventory/
│       │   └── inventory_screen.dart     # Inventory CRUD + stock alerts
│       └── profile/
│           └── profile_screen.dart       # User profile + sign out
│
├── android/
│   ├── build.gradle
│   └── app/
│       ├── build.gradle
│       └── src/main/AndroidManifest.xml
│
├── ios/
│   └── Runner/Info.plist
│
├── firestore.rules                       # Firestore security rules
└── pubspec.yaml
```

---

## 🚀 Setup Instructions

### Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | ≥ 3.0.0 |
| Dart | ≥ 3.0.0 |
| Android Studio / Xcode | Latest |
| Firebase CLI | Latest |
| Node.js | ≥ 18 (for Firebase CLI) |

### Step 1 — Clone & Install Flutter

```bash
# Install Flutter (if not already)
# https://flutter.dev/docs/get-started/install

# Clone the project
cd your-projects-directory

# Install dependencies
cd dubai_coffee_pos
flutter pub get
```

### Step 2 — Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Add project** → Name it `dubai-coffee-pos`
3. Enable **Google Analytics** (optional but recommended)
4. In **Authentication** → Sign-in method → Enable **Email/Password**
5. In **Firestore Database** → Create database → Start in **production mode**

### Step 3 — Connect Flutter to Firebase

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Add to PATH if needed:
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Log in to Firebase
firebase login

# Configure Flutter app (run from project root)
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This auto-generates `lib/firebase_options.dart` with your real credentials.

### Step 4 — Deploy Firestore Security Rules

```bash
# Install Firebase CLI
npm install -g firebase-tools

firebase login
firebase init firestore   # select your project
# copy firestore.rules content, or it will use the file automatically

firebase deploy --only firestore:rules
```

### Step 5 — Add Firebase config files

#### Android
- In Firebase Console → Project Settings → Add Android app
- Package name: `com.dubaicoffee.pos`
- Download `google-services.json`
- Place it at: `android/app/google-services.json`

#### iOS
- In Firebase Console → Project Settings → Add iOS app
- Bundle ID: `com.dubaicoffee.pos`
- Download `GoogleService-Info.plist`
- Place it at: `ios/Runner/GoogleService-Info.plist`
- Open Xcode → drag file into Runner folder → Add to target

### Step 6 — Run the App

```bash
# List available devices
flutter devices

# Run on Android
flutter run -d android

# Run on iOS (requires macOS + Xcode)
flutter run -d ios

# Build APK (Android release)
flutter build apk --release

# Build iOS archive (macOS only)
flutter build ios --release
```

---

## 🔐 Authentication & Roles

| Feature | Barista | Admin |
|---------|---------|-------|
| Process orders | ✅ | ✅ |
| View order history | ✅ | ✅ |
| Kitchen display | ✅ | ✅ |
| Adjust inventory stock | ✅ | ✅ |
| Add/edit/delete inventory | ❌ | ✅ |
| View reports/analytics | ❌ | ✅ |
| Void orders | ✅ | ✅ |

**First user:** Register through the app and select **Admin** role. Subsequent staff members register as **Barista**.

---

## 🗄️ Firebase / Firestore Collections

| Collection | Description |
|------------|-------------|
| `users` | Staff accounts (name, email, role) |
| `menuItems` | Product catalog (seeded automatically) |
| `orders` | All orders (paid, voided, held) |
| `inventory` | Ingredient/supply stock levels |

### Seed Data
Menu items and inventory items are **auto-seeded on first launch** — no manual setup needed.

---

## ✨ Features Implemented

### 1. Authentication System
- Email/password login & registration
- Role-based access: Admin vs Barista
- Session persistence (stays logged in)
- Secure form validation

### 2. Customer Name Flow
- Barista must enter customer name before any item is added
- Tapping any menu item without a customer name opens the name prompt
- Customer name shown on: cart, receipt, order history, kitchen display

### 3. POS / Cashier
- Menu grid with categories (Hot Coffee, Cold Drinks, Pastries, Add-ons)
- Search across all menu items
- Add/remove items, adjust quantities
- Discount system: Percent, Fixed, Senior/PWD (20%), Staff (15%)
- VAT (12%) calculation
- Payment methods: Cash, GCash, Card, PayMaya
- Cash change calculator
- Digital receipt with full order summary

### 4. Order History
- Real-time stream from Firestore
- Filter by status, payment method
- Search by customer name, item, order number
- Expandable rows with full order details
- Void order functionality
- Stats: Total sales, order count, avg order, voided count

### 5. Kitchen Display (KDS)
- Shows active paid orders in real time
- Tap items to mark as done
- "Bump" to remove from display when complete
- Customer name visible on each card
- Live clock

### 6. Reports (Admin only)
- Revenue, order count, avg order value, top item
- Top 5 selling items bar chart
- Payment method pie chart (fl_chart)
- Hourly sales bar chart

### 7. Inventory Management
- Full CRUD: Add, Edit, Delete items
- Stock adjustment (add/deduct)
- Low stock and out-of-stock alerts
- Category filter
- Role-based: only admins can add/edit/delete

### 8. Profile
- View account info and role
- Permission overview
- Sign out

---

## 📱 Mobile Optimizations

- `DraggableScrollableSheet` for cart and receipt
- `IndexedStack` for instant tab switching (no rebuilds)
- `StreamBuilder` everywhere for real-time Firestore updates
- Responsive grid: 3 columns (tablet), 2 columns (phone)
- Safe area aware (notches, home bar)
- Touch-friendly tap targets (min 44×44px)
- Smooth `AnimatedContainer` transitions on menu cards

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x |
| Language | Dart 3.x |
| Backend | Firebase (BaaS) |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| State Management | Provider |
| Charts | fl_chart |
| Fonts | Google Fonts (DM Sans) |

---

## 🐛 Troubleshooting

**"firebase_options.dart not found"**
→ Run `flutterfire configure` to generate it.

**"google-services.json not found"**
→ Download from Firebase Console → Project Settings → Android app.

**Build fails on iOS**
→ Open `ios/Runner.xcworkspace` in Xcode → set your Team in Signing & Capabilities.

**Firestore permission denied**
→ Deploy `firestore.rules` using `firebase deploy --only firestore:rules`.

**App crashes on launch (Android)**
→ Check `minSdkVersion` is 21 in `android/app/build.gradle`.
