"""
Upload schemes from CSV to Firestore.

This script reads one sample document from the existing "schemes" collection,
prints its field structure, compares CSV columns to Firestore fields,
and then inserts only new documents using schemeId as the document ID.
Existing documents are never overwritten.
"""

import argparse
import csv
import os
import re
import sys
from typing import Any, Dict, List, Optional, Set, Tuple

import firebase_admin
from firebase_admin import credentials, firestore

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DEFAULT_CSV_PATH = os.path.join(PROJECT_ROOT, "data", "public_welfare_schemes.csv")
DEFAULT_SERVICE_ACCOUNT_PATH = os.path.join(PROJECT_ROOT, "serviceAccountKey.json")
FIRESTORE_COLLECTION = "schemes"
ARRAY_FIELDS = {"requiredDocuments", "importantDocuments"}
NUMERIC_FIELDS = {"minAge", "maxAge", "maxIncomeINR", "incomeLimit"}
NULL_STRINGS = {"NA", "N/A", "NONE", "NULL", ""}
FIELD_ALIASES = {
    "Scheme_ID": "schemeId",
    "scheme_id": "schemeId",
    "schemeid": "schemeId",
    "SchemeId": "schemeId",
    "Scheme_Name": "schemeName",
    "scheme_name": "schemeName",
    "SchemeName": "schemeName",
    "Important_Documents": "importantDocuments",
    "important_documents": "importantDocuments",
    "Required_Documents": "requiredDocuments",
    "required_documents": "requiredDocuments",
}


def normalize_field_name(field_name: str) -> str:
    if field_name is None:
        return ""
    field = field_name.strip()
    if not field:
        return ""
    return FIELD_ALIASES.get(field, field)


def parse_array_field(value: Any) -> Optional[List[str]]:
    if value is None:
        return None
    if isinstance(value, list):
        return [str(item).strip() for item in value if item is not None and str(item).strip()]
    if not isinstance(value, str):
        return None
    cleaned = value.strip()
    if not cleaned or cleaned.upper() in NULL_STRINGS:
        return None
    items = [item.strip() for item in re.split(r"[,;]", cleaned) if item.strip()]
    return items or None


def parse_numeric_field(value: Any) -> Optional[Any]:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        if isinstance(value, float) and value.is_integer():
            return int(value)
        return int(value) if isinstance(value, int) else value
    if not isinstance(value, str):
        return None
    text = value.strip()
    if not text or text.upper() in NULL_STRINGS:
        return None
    text = text.replace("₹", "").replace("Rs.", "").replace("Rs", "")
    text = re.sub(r"[ ,]+", "", text)
    if not text:
        return None
    try:
        if "." in text:
            number = float(text)
            return int(number) if number.is_integer() else number
        return int(text)
    except ValueError:
        try:
            return float(text)
        except ValueError:
            return None


def load_csv_rows(csv_path: str) -> Tuple[List[Dict[str, Any]], List[str]]:
    with open(csv_path, newline="", encoding="utf-8-sig") as csvfile:
        reader = csv.DictReader(csvfile)
        headers = [header for header in (reader.fieldnames or []) if header is not None]
        rows = [row for row in reader]
    return rows, headers


def print_firestore_sample_structure(db: firestore.Client) -> Set[str]:
    collection_ref = db.collection(FIRESTORE_COLLECTION)
    docs = list(collection_ref.limit(1).stream())
    if not docs:
        print("ℹ️  No existing documents found in the 'schemes' collection.")
        return set()

    sample = docs[0]
    sample_data = sample.to_dict() or {}
    print(f"✅ Existing document sample ID: {sample.id}")
    print("Existing document structure:")
    for key, value in sorted(sample_data.items()):
        print(f"  - {key}: {type(value).__name__}")
    return set(sample_data.keys())


def compare_csv_and_firestore_fields(csv_headers: List[str], firestore_fields: Set[str]) -> None:
    normalized_headers = [normalize_field_name(h) for h in csv_headers]
    mapped_headers = [h for h in normalized_headers if h]

    print("\nCSV columns found:")
    for header in csv_headers:
        print(f"  - {header}")

    print("\nMapped Firestore fields from CSV headers:")
    for header in mapped_headers:
        print(f"  - {header}")

    if firestore_fields:
        extra_csv_fields = [h for h in mapped_headers if h not in firestore_fields]
        missing_firestone_fields = [f for f in sorted(firestore_fields) if f not in mapped_headers]

        print("\nComparison with existing Firestore document fields:")
        if extra_csv_fields:
            print("  - CSV columns not present in the sample Firestore document:")
            for field in sorted(set(extra_csv_fields)):
                print(f"      • {field}")
        else:
            print("  - All CSV fields appear in the sample Firestore document or were normalized.")

        if missing_firestone_fields:
            print("  - Sample Firestore document fields not present in CSV:")
            for field in missing_firestone_fields:
                print(f"      • {field}")
        else:
            print("  - No fields in the sample Firestore document are missing from the CSV header list.")
    else:
        print("\nNo Firestore schema sample available to compare against.")


def build_firestore_document(row: Dict[str, Any]) -> Dict[str, Any]:
    firestore_data: Dict[str, Any] = {}
    for raw_key, raw_value in row.items():
        field_name = normalize_field_name(raw_key)
        if not field_name:
            continue

        if raw_value is None:
            continue

        if isinstance(raw_value, str):
            raw_value = raw_value.strip()

        if raw_value == "" or (isinstance(raw_value, str) and raw_value.upper() in NULL_STRINGS):
            continue

        if field_name in ARRAY_FIELDS:
            parsed = parse_array_field(raw_value)
            if parsed:
                firestore_data[field_name] = parsed
            continue

        if field_name in NUMERIC_FIELDS:
            parsed = parse_numeric_field(raw_value)
            if parsed is not None:
                firestore_data[field_name] = parsed
            continue

        firestore_data[field_name] = raw_value

    return firestore_data


def initialize_firestore(service_account_path: str) -> firestore.Client:
    if not firebase_admin._apps:
        if service_account_path and os.path.exists(service_account_path):
            firebase_admin.initialize_app(credentials.Certificate(service_account_path))
        else:
            print("ℹ️  No service account key found, falling back to Application Default Credentials.")
            print("   Run `gcloud auth application-default login` and set project with")
            print("   `gcloud config set project yojana-suchak-backend` before running.")
            firebase_admin.initialize_app(credentials.ApplicationDefault())
    app = firebase_admin.get_app()
    print(f"Connected Firebase project ID: {app.project_id}")
    return firestore.client()


def upload_csv_to_firestore(csv_path: str, service_account_path: str) -> bool:
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    db = initialize_firestore(service_account_path)
    rows, csv_headers = load_csv_rows(csv_path)

    print("\n--- Existing Firestore schema check ---")
    firestore_fields = print_firestore_sample_structure(db)
    compare_csv_and_firestore_fields(csv_headers, firestore_fields)

    print("\n--- Uploading new documents ---")
    added_count = 0
    skipped_existing_count = 0
    skipped_invalid_count = 0

    for row_index, row in enumerate(rows, start=2):
        document = build_firestore_document(row)
        doc_id = document.get("schemeId")
        if not doc_id:
            print(f"⚠️  Row {row_index}: Missing schemeId, skipping")
            skipped_invalid_count += 1
            continue

        if len(document) <= 1:
            print(f"⚠️  Row {row_index}: No uploadable fields beyond schemeId, skipping")
            skipped_invalid_count += 1
            continue

        doc_ref = db.collection(FIRESTORE_COLLECTION).document(str(doc_id))
        snapshot = doc_ref.get()
        if snapshot.exists:
            skipped_existing_count += 1
            continue

        doc_ref.set(document)
        added_count += 1

    print("\n--- Upload summary ---")
    print(f"Records added: {added_count}")
    print(f"Records skipped (already existing): {skipped_existing_count}")
    print(f"Records skipped (invalid or missing schemeId): {skipped_invalid_count}")

    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Upload new scheme documents from CSV into Firestore.")
    parser.add_argument("--csv", default=DEFAULT_CSV_PATH, help="Path to the CSV file.")
    parser.add_argument(
        "--service-account",
        default=DEFAULT_SERVICE_ACCOUNT_PATH,
        help="Path to the Firebase service account JSON key file. If missing, uses Application Default Credentials.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    print("=" * 70)
    print("🚀 FIRESTORE CSV SAFE UPLOAD")
    print("=" * 70)
    print(f"CSV file: {args.csv}")
    print(f"Service account key: {args.service_account}\n")

    try:
        upload_csv_to_firestore(args.csv, args.service_account)
        sys.exit(0)
    except FileNotFoundError as error:
        print(f"❌ {error}")
        sys.exit(1)
    except Exception as error:
        print(f"❌ Unexpected error: {error}")
        sys.exit(1)
