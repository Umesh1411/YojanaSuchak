# 🚀 QUICK CSV UPLOAD CHECKLIST

## 📍 FILE LOCATIONS

| File | Location | Status |
|------|----------|--------|
| **CSV (schemes)** | `assets/data/scheme.csv` | ✅ Ready |
| **Upload script** | `scripts/upload_csv_to_firestore.py` | ✅ Created |
| **Service account key** | `serviceAccountKey.json` (project root) | ⏳ Need to add |

---

## 3-MINUTE SETUP

### ✅ Step 1: Get Firebase Credentials (2 minutes)
```
1. Visit: https://console.firebase.google.com/
2. Select Yojana Suchak project
3. Settings (⚙️) → Service Accounts tab
4. Click "Generate new private key"
5. Save downloaded JSON as "serviceAccountKey.json" in project root
```

### ✅ Step 2: Install Packages (1 minute)
```bash
pip install firebase-admin pandas
```

### ✅ Step 3: Run Upload (automatic)
```bash
python scripts/upload_csv_to_firestore.py
```

---

## 🎯 CSV → FIRESTORE MAPPING

Your CSV columns are converted automatically:

```
Scheme_ID        →  schemeId
Scheme_Name      →  schemeName
Min_Age          →  minAge
Max_Age          →  maxAge
Max_Income_INR   →  maxIncomeINR
Gender_Eligible  →  genderEligible
Important_Docs   →  importantDocuments (array)
(+ searchText field added automatically)
```

---

## 🔐 SECURITY CHECKLIST

- [ ] `serviceAccountKey.json` is in `.gitignore` ✅ (already should be)
- [ ] Never commit the service account key
- [ ] Key is kept only on your local machine
- [ ] Use environment variable for production (Firebase Cloud Functions)

---

## 🧪 VERIFY UPLOAD SUCCESS

After running the script:

1. **Open Firebase Console**
2. **Go to Firestore Database**
3. **Check "schemes" collection exists**
4. **Click a document (e.g., "CHD_01")**
5. **Verify fields are correct (schemeId, schemeName, minAge, etc.)**

✅ If you see your data = **SUCCESS!**

---

## 🆘 QUICK FIXES

| Problem | Solution |
|---------|----------|
| "Service account key not found" | Save key as `serviceAccountKey.json` in project root |
| Script won't run | Install: `pip install firebase-admin pandas` |
| Data not appearing | Refresh Firebase Console or check project ID in key |
| Permission denied error | Verify service account key is correct |

---

## 📝 WHAT GETS UPLOADED

- ✅ All schemes from `scheme.csv`
- ✅ Converted to proper Firestore field names
- ✅ Arrays handled correctly (Important_Documents)
- ✅ Numeric fields converted to integers
- ✅ Search text field added
- ✅ Existing schemes NOT overwritten (merge=True)

---

**Ready? Run: `python scripts/upload_csv_to_firestore.py`**
