# GitHub Pages Setup Guide for app-ads.txt

This guide will help you host your `app-ads.txt` file on GitHub Pages to satisfy Google AdMob requirements.

## What is app-ads.txt?

App-ads.txt is a text file that helps prevent ad fraud by publicly declaring which ad networks are authorized to sell your app's ad inventory. It's similar to ads.txt for websites.

## Why Do You Need It?

- **Required by AdMob**: Google AdMob now requires app-ads.txt for optimal ad serving
- **Prevents Ad Fraud**: Ensures only authorized sellers can sell your ad inventory
- **Maximizes Revenue**: Apps without app-ads.txt may see reduced ad fill rates
- **Builds Trust**: Shows advertisers that your app is legitimate

---

## Step-by-Step: Host app-ads.txt on GitHub Pages

### Step 1: Create a GitHub Repository for Your Website

1. **Go to GitHub** and log in: https://github.com
2. **Click the "+" icon** in the top-right corner → "New repository"
3. **Name your repository**: `YOUR-USERNAME.github.io`
   - Replace `YOUR-USERNAME` with your actual GitHub username
   - Example: If your username is `helal-dev`, name it `helal-dev.github.io`
   - ⚠️ **Important**: The name MUST be exactly `yourusername.github.io` for GitHub Pages to work
4. **Make it Public** (required for free GitHub Pages)
5. **Check "Add a README file"** (optional but recommended)
6. **Click "Create repository"**

### Step 2: Upload app-ads.txt to Your Repository

#### Option A: Upload via GitHub Web Interface (Easiest)

1. **Go to your new repository** (https://github.com/YOUR-USERNAME/YOUR-USERNAME.github.io)
2. **Click "Add file"** → "Upload files"
3. **Drag and drop** the `app-ads.txt` file from your project folder:
   ```
   D:\my-projects\untitled\app-ads.txt
   ```
4. **Scroll down** and click "Commit changes"
5. **Done!** The file is now uploaded

#### Option B: Upload via Git Command Line

```bash
# Navigate to a folder where you want to clone the repo
cd D:\my-projects

# Clone your new repository
git clone https://github.com/YOUR-USERNAME/YOUR-USERNAME.github.io.git

# Navigate into the repository
cd YOUR-USERNAME.github.io

# Copy the app-ads.txt file from your project
copy D:\my-projects\untitled\app-ads.txt app-ads.txt

# Add, commit, and push
git add app-ads.txt
git commit -m "Add app-ads.txt for AdMob verification"
git push origin main
```

### Step 3: Enable GitHub Pages

1. **Go to your repository** on GitHub
2. **Click "Settings"** tab (top of the page)
3. **Scroll down** to the "Pages" section in the left sidebar
4. **Under "Source"**, select:
   - Branch: `main` (or `master`)
   - Folder: `/ (root)`
5. **Click "Save"**
6. **Wait 1-2 minutes** for GitHub to build your site
7. **Refresh the page** - you should see: "Your site is published at https://YOUR-USERNAME.github.io/"

### Step 4: Verify app-ads.txt is Accessible

1. **Open your browser** and go to:
   ```
   https://YOUR-USERNAME.github.io/app-ads.txt
   ```
2. **You should see**:
   ```
   google.com, pub-4425611562080784, DIRECT, f08c47fec0942fa0
   ```
3. **If you see this text**, your file is correctly hosted! ✅

### Step 5: Add the URL to Your App Listing

#### For Google Play Console:

1. **Go to Google Play Console**: https://play.google.com/console
2. **Select your app** (Quran by Helal)
3. **Go to "Store presence"** → "App content"
4. **Scroll to "Developer website"** or "Privacy policy"
5. **Enter your GitHub Pages URL**:
   ```
   https://YOUR-USERNAME.github.io
   ```
6. **Save changes**

#### For AdMob Console:

1. **Go to AdMob**: https://apps.admob.com
2. **Click "Apps"** in the left sidebar
3. **Find your app** (Quran by Helal)
4. **Click "App settings"**
5. **Scroll to "Developer website"**
6. **Enter your GitHub Pages URL**:
   ```
   https://YOUR-USERNAME.github.io
   ```
7. **Save**

### Step 6: Verify in AdMob

1. **Go to AdMob Console** → Your App
2. **Look for app-ads.txt status** (may take 24-48 hours to update)
3. **Once verified**, the warning should disappear
4. **Status should show**: ✅ "app-ads.txt verified"

---

## Your app-ads.txt File Contents

Your `app-ads.txt` file contains:

```
google.com, pub-4425611562080784, DIRECT, f08c47fec0942fa0
```

### What this means:
- **google.com** = The ad network (Google AdMob)
- **pub-4425611562080784** = Your unique publisher ID
- **DIRECT** = You have a direct relationship with Google
- **f08c47fec0942fa0** = Google's certification authority ID (standard for all Google ads)

---

## Troubleshooting

### "404 Not Found" when accessing app-ads.txt

**Solution**:
1. Check that the file is in the **root** of your repository (not in a subfolder)
2. Wait 2-5 minutes after uploading for GitHub Pages to rebuild
3. Try accessing with and without `www.`:
   - https://YOUR-USERNAME.github.io/app-ads.txt
   - https://www.YOUR-USERNAME.github.io/app-ads.txt

### GitHub Pages not showing up in Settings

**Solution**:
1. Make sure your repository is **public** (not private)
2. Make sure the repository name is exactly `YOUR-USERNAME.github.io`
3. Check that you have at least one file (like README.md) committed

### AdMob still shows warning after 48 hours

**Solution**:
1. Verify the file is accessible at: https://YOUR-USERNAME.github.io/app-ads.txt
2. Check that you added the website URL in both:
   - Google Play Console (Store presence → App content)
   - AdMob Console (App settings)
3. Make sure the URL is **exactly** your GitHub Pages URL (no extra paths)

### Want to use a custom domain instead?

If you want to use your own domain (e.g., `quranbyhelal.com`) instead of GitHub Pages:

1. **Buy a domain** from any domain registrar (Namecheap, GoDaddy, etc.)
2. **Configure DNS** to point to GitHub Pages:
   - Add an `A` record pointing to GitHub's IPs
   - Add a `CNAME` record with your GitHub Pages URL
3. **Update repository settings** with your custom domain
4. **Full guide**: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site

---

## Quick Reference

**Your GitHub Pages URL format**:
```
https://YOUR-USERNAME.github.io
```

**Your app-ads.txt URL**:
```
https://YOUR-USERNAME.github.io/app-ads.txt
```

**File location in repository**:
```
YOUR-USERNAME.github.io/
├── app-ads.txt        ← Must be in root directory
├── README.md          ← Optional
└── index.html         ← Optional (for a homepage)
```

---

## Next Steps After Setup

1. ✅ **Verify file is accessible** at your GitHub Pages URL
2. ✅ **Add website URL** to Google Play Console
3. ✅ **Add website URL** to AdMob Console
4. ⏳ **Wait 24-48 hours** for verification
5. ✅ **Check AdMob Console** for "app-ads.txt verified" status

---

## Optional: Add a Simple Homepage

If you want to add a homepage to your GitHub Pages site (instead of just app-ads.txt), create an `index.html`:

```html
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quran by Helal - قرآن من هلال</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.1);
            padding: 40px;
            border-radius: 20px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 2.5em; margin-bottom: 20px; }
        p { font-size: 1.2em; line-height: 1.6; }
        a {
            display: inline-block;
            margin-top: 20px;
            padding: 15px 30px;
            background: white;
            color: #667eea;
            text-decoration: none;
            border-radius: 30px;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>قرآن من هلال</h1>
        <h2>Quran by Helal</h2>
        <p>تطبيق قراءة القرآن الكريم مع التلاوة الصوتية والعديد من الميزات</p>
        <p>A beautiful Quran reader app with audio recitation and many features</p>
        <a href="https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME" target="_blank">
            Download on Google Play
        </a>
    </div>
</body>
</html>
```

Upload this file the same way you uploaded `app-ads.txt`.

---

**Need Help?** Contact: helal.tech.studio@gmail.com
