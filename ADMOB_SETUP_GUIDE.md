# Google AdMob Setup Guide for Quran by Helal

This guide will walk you through setting up Google AdMob for rewarded ads in your app.

---

## 📋 **Prerequisites**

- Google account
- Published or ready-to-publish Android app
- App package name: `com.helal.quran`

---

## 🚀 **Step 1: Create AdMob Account**

1. Go to [Google AdMob](https://admob.google.com/)
2. Click **"Get started"**
3. Sign in with your Google account
4. Accept the AdMob Terms & Conditions
5. Choose your country and timezone
6. Click **"Continue to AdMob"**

---

## 📱 **Step 2: Add Your App**

1. In AdMob dashboard, click **"Apps"** in left sidebar
2. Click **"Add app"** button
3. Select **"Android"**
4. Answer: **"Is your app published on Google Play?"**
   - If YES: AdMob will fetch app details automatically
   - If NO: Enter app details manually
5. Enter app name: **"Quran by Helal"**
6. Enter package name: **`com.helal.quran`**
7. Click **"Add app"**

**IMPORTANT:** Copy the **App ID** shown (format: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`)

---

## 🎬 **Step 3: Create Rewarded Ad Unit**

1. After adding the app, click **"Ad units"** tab
2. Click **"Add ad unit"**
3. Select **"Rewarded"** ad format
4. Configure the ad unit:
   - **Ad unit name:** `Support Developer Reward`
   - **Reward item:** `Support` (you can change this)
   - **Reward amount:** `1` (doesn't affect anything, just a label)
5. Click **"Create ad unit"**

**IMPORTANT:** Copy the **Ad Unit ID** shown (format: `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY`)

---

## 🔧 **Step 4: Update Android Configuration**

### **4.1: Add AdMob App ID to AndroidManifest.xml**

1. Open: `android/app/src/main/AndroidManifest.xml`
2. Find the `<application>` tag
3. Add this INSIDE the `<application>` tag (before the closing `</application>`):

```xml
<!-- AdMob App ID -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
```

**⚠️ Replace** `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` with your **real AdMob App ID** from Step 2!

**Example:**
```xml
<application
    android:label="Quran by Helal"
    android:name=".MyApplication"
    android:icon="@mipmap/ic_launcher">

    <!-- AdMob App ID -->
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-1234567890123456~1234567890"/>

    <activity
        android:name=".MainActivity"
        ...
```

---

## 💻 **Step 5: Update Ad Unit IDs in Code**

### **5.1: Open AdMobService**

Open: `lib/services/admob_service.dart`

### **5.2: Update Android Ad Unit ID**

Find this line (around line 24):
```dart
static const String _androidRewardedAdUnitId = _testRewardedAdUnitId; // TODO: Replace with real ID
```

Replace it with your **real Ad Unit ID** from Step 3:
```dart
static const String _androidRewardedAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
```

**Example:**
```dart
static const String _androidRewardedAdUnitId = 'ca-app-pub-1234567890123456/1234567890';
```

### **5.3: iOS (If you plan to release on iOS later)**

Find this line:
```dart
static const String _iosRewardedAdUnitId = _testRewardedAdUnitId; // TODO: Replace with real ID
```

Create an iOS ad unit in AdMob (same process as Step 3), then update:
```dart
static const String _iosRewardedAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
```

---

## 🧪 **Step 6: Test the Ads**

### **6.1: Test Mode (Recommended for Development)**

The app will automatically use **test ads** in debug mode. This is safe and prevents invalid traffic.

**To test:**
1. Run the app: `flutter run`
2. Open Features screen
3. Tap "دعم المطور" (Support Developer)
4. Confirm to watch ad
5. You should see a **test ad** with a label "Test Ad"
6. Watch the full ad to test completion flow

### **6.2: Production Mode**

⚠️ **NEVER** click your own real ads during testing! This can get your AdMob account banned.

**To test production ads safely:**
1. Add your device as a test device in AdMob
2. In AdMob dashboard: **Settings** → **Test devices** → **Add test device**
3. Get your device's advertising ID:
   - Android: Settings → Google → Ads → Your advertising ID
4. Add the ID to AdMob
5. Build release version: `flutter build apk --release`
6. Install and test

---

## 📊 **Step 7: Monitor Ad Performance**

1. Go to [AdMob Dashboard](https://admob.google.com/)
2. Click **"Dashboard"** in left sidebar
3. View metrics:
   - **Estimated earnings**: How much you've earned
   - **Impressions**: How many ads were shown
   - **Match rate**: How often ads were available
   - **Show rate**: How often ads were actually shown

**Note:** It takes 24-48 hours for data to appear after first ad is shown.

---

## 💰 **Step 8: Set Up Payments (Optional)**

1. In AdMob dashboard, click **"Payments"** in left sidebar
2. Add payment method:
   - Bank account (ACH/Wire transfer)
   - Or other available methods in your country
3. Complete tax information
4. Set payment threshold (default: $100 USD)

**Note:** You'll receive payment when you reach the threshold.

---

## ✅ **Step 9: Final Checklist Before Release**

- [ ] AdMob App ID added to `AndroidManifest.xml`
- [ ] Real Ad Unit IDs updated in `admob_service.dart`
- [ ] Test ads work in debug mode
- [ ] Privacy policy updated (already done ✅)
- [ ] Google Play Data Safety form updated (see below)
- [ ] App tested on real device
- [ ] No test device IDs left in production code

---

## 📱 **Step 10: Update Google Play Data Safety**

When submitting to Google Play Console:

1. Go to **App content** → **Data safety**
2. Add data collection disclosure:

**Data collected:**
- ✅ **Device or other IDs** (Advertising ID)
- ✅ **App interactions** (Ad views, ad clicks)

**Data usage:**
- Purpose: **Advertising or marketing**
- Data is **ephemeral** (not stored permanently by you)
- Data is shared with **Google AdMob**

**User control:**
- ✅ Users can opt out of personalized ads (in device settings)
- ✅ Ads are optional (user chooses when to watch)

3. Save and publish

---

## 🔍 **Troubleshooting**

### **Problem: "No ad available"**

**Causes:**
- App is new (AdMob needs 1-2 hours to start serving ads)
- Low ad inventory in your region
- Ad request limit reached

**Solutions:**
- Wait 1-2 hours after first build
- Test with VPN to different region
- Check AdMob dashboard for errors

### **Problem: Ads not loading**

**Check:**
1. Internet connection is working
2. AdMob App ID is correct in `AndroidManifest.xml`
3. Ad Unit ID is correct in `admob_service.dart`
4. App is built in release mode (for production ads)
5. Check logcat for errors: `flutter logs | grep AdMob`

### **Problem: Account warnings**

**Common issues:**
- Clicking your own ads (DON'T DO THIS!)
- Invalid traffic patterns
- App policy violations

**Solution:**
- Never click your own real ads
- Use test ads for development
- Follow AdMob policies

---

## 📚 **Additional Resources**

- [AdMob Help Center](https://support.google.com/admob)
- [AdMob Policies](https://support.google.com/admob/answer/6128543)
- [Flutter Google Mobile Ads Documentation](https://pub.dev/packages/google_mobile_ads)
- [Rewarded Ads Best Practices](https://support.google.com/admob/answer/9341964)

---

## 🎯 **Quick Reference**

### **Your AdMob IDs:**

```
AdMob App ID (for AndroidManifest.xml):
ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY

Android Rewarded Ad Unit ID (for admob_service.dart):
ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY

iOS Rewarded Ad Unit ID (if needed):
ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY
```

### **Files to Update:**

1. `android/app/src/main/AndroidManifest.xml` - Add App ID
2. `lib/services/admob_service.dart` - Update Ad Unit IDs (lines 23-24)

---

## ✨ **You're Done!**

Your app is now configured with AdMob rewarded ads. Users can support you by watching ads whenever they want! 🎉

**Next steps:**
1. Test thoroughly
2. Build release version
3. Upload to Google Play
4. Monitor earnings in AdMob dashboard

Good luck! 🚀
