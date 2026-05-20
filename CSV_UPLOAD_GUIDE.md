# 🚀 FIRESTORE CSV UPLOAD GUIDE FOR YOJANA SUCHAK

## 📍 WHERE IS YOUR CSV?

Your **scheme.csv** is already at:
```
assets/data/scheme.csv
```

✅ **Good news:** The CSV is in the right place!

---

## 🔑 STEP 1: Get Firebase Service Account Key (CRITICAL)

### Why do you need it?
The service account key is like your database password - it lets the script authenticate with Firebase.

### How to get it:

1. **Go to Firebase Console:**
   - https://console.firebase.google.com/

2. **Select your Yojana Suchak project**

3. **Navigate to Settings → Service Accounts:**
   - Click gear icon ⚙️ (top left)
   - Select "Project Settings"
   - Go to "Service Accounts" tab

4. **Generate New Private Key:**
   - Click "Generate new private key" button
   - A JSON file will download

5. **Save it in your project root:**
   ```
   YojanaSuchak/serviceAccountKey.json
   ```
   
   ⚠️ **IMPORTANT:**
   - Rename it exactly to `serviceAccountKey.json`
   - **NEVER** commit it to Git (it's in `.gitignore`)
   - Keep it secret!

---

## 💾 STEP 2: Install Required Packages

Run this command in your project root:

```bash
pip install firebase-admin pandas
```

**If using conda:**
```bash
conda install firebase-admin pandas
```

---

## 🎯 STEP 3: Run the Upload Script

Navigate to your project root and run:

```bash
python scripts/upload_csv_to_firestore.py
```

### What the script does:
✅ Reads `assets/data/scheme.csv`
✅ Converts CSV column names to Firestore format:
   - `Scheme_ID` → `schemeId`
   - `Min_Age` → `minAge`
   - `Max_Income_INR` → `maxIncomeINR`
   - etc.

✅ Handles arrays properly (Important_Documents → array)
✅ Removes "NA" values
✅ Adds `searchText` field for fast searching
✅ Uses `merge=True` to NOT overwrite existing schemes
✅ Shows upload progress

### Expected output:
```
============================================================
🚀 FIRESTORE CSV UPLOAD SCRIPT
============================================================

📁 CSV Location: .../assets/data/scheme.csv
🔑 Service Key: .../serviceAccountKey.json

🔄 Initializing Firebase...
📖 Loading CSV from: .../assets/data/scheme.csv
✅ Found 150 schemes to upload

✅ Uploaded 10 schemes...
✅ Uploaded 20 schemes...
...
✅ Upload complete!
   Total uploaded: 150/150 schemes
```

---

## 📊 Firestore Structure After Upload

```
Firestore Collections
├── schemes (collection)
│   ├── CHD_01 (document)
│   │   ├── schemeId: "CHD_01"
│   │   ├── schemeName: "Integrated Child Development Services"
│   │   ├── minAge: 0
│   │   ├── maxAge: 6
│   │   ├── maxIncomeINR: [not set]
│   │   ├── importantDocuments: ["Birth Certificate", "Anganwadi Registration"]
│   │   ├── searchText: "integrated child development services nutrition immunization..."
│   │   └── ...other fields...
│   │
│   ├── CHD_02 (document)
│   │   └── ...
```

---

## ⚙️ FIRESTORE INDEXING (Optional but Recommended)

For your eligibility filters to work fast, create these composite indexes:

In **Firebase Console** → Collections → "schemes" → Indexes:

Add these indexes:
1. **minAge** (Ascending)
2. **maxAge** (Ascending)
3. **maxIncomeINR** (Ascending)
4. **genderEligible** (Ascending)
5. **occupationEligible** (Ascending)
6. **categoryEligible** (Ascending)

**Composite index example (if filtering by multiple fields):**
```
Fields: 
- minAge (Ascending)
- maxIncomeINR (Ascending)
```

✅ This makes your eligibility engine super fast!

---

## 🔍 CSV COLUMN MAPPING

| CSV Column | Firestore Field | Type | Example |
|-----------|-----------------|------|---------|
| Scheme_ID | schemeId | String | "CHD_01" |
| Scheme_Name | schemeName | String | "ICDS" |
| State | state | String | "India" |
| Min_Age | minAge | Integer | 0 |
| Max_Age | maxAge | Integer | 6 |
| Max_Income_INR | maxIncomeINR | Integer | 300000 |
| Important_Documents | importantDocuments | Array | ["Aadhaar", "Address Proof"] |
| ... | searchText | String | (auto-generated) |

---

## ✅ CHECKLIST BEFORE UPLOAD

- [ ] CSV file exists at `assets/data/scheme.csv`
- [ ] Service account key downloaded from Firebase
- [ ] Key saved as `serviceAccountKey.json` in project root
- [ ] `firebase-admin` and `pandas` installed (`pip install firebase-admin pandas`)
- [ ] Project root is the directory containing `pubspec.yaml`
- [ ] You've reviewed the CSV data for obvious errors

---

## 🆘 TROUBLESHOOTING

### Error: "Service account key not found"
✅ **Solution:** Make sure `serviceAccountKey.json` is in your project root (same directory as `pubspec.yaml`)

### Error: "Collection 'schemes' does not exist"
✅ **No problem!** Firestore will create it automatically when you upload

### Error: "DataFrame is empty"
✅ **Check:** The CSV file at `assets/data/scheme.csv` has data

### Error: "Firebase error: Permission denied"
✅ **Check:** 
- Service account key is correct
- Firestore rules allow writes from this service account

### Script runs but no data appears
✅ **Check:**
- Go to Firebase Console → Firestore Database
- Verify the "schemes" collection exists
- Click on a document to see fields

---

## 🎯 NEXT STEPS

After upload:

1. **Verify in Firebase Console:**
   - Open Firestore Database
   - Check "schemes" collection
   - Verify document structure

2. **Update your app** to use Firestore instead of JSON:
   - In `lib/services/`, update data loading to query Firestore
   - Example query: `db.collection('schemes').where('minAge', '<=', userAge).get()`

3. **Test filtering** with your eligibility engine

---

## 📝 NOTES

- **merge=True:** Won't delete existing schemes, only adds/updates
- **searchText:** Automatically generated for text search functionality
- **NaN handling:** Null values are skipped (not uploaded)
- **Array fields:** Split by semicolon (;) in CSV

---

**✨ You're all set! Run the script and your CSV will be in Firestore!**
