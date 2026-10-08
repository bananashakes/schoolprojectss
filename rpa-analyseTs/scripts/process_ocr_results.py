import csv
import os
import re
import traceback
from datetime import datetime

INPUT_CSV = os.path.join("output", "ocr_results.csv")
PROCESSED_CSV = os.path.join("output", "processed_stock_results.csv")
ERROR_LOG_TXT = os.path.join("output", "python_error_log.txt")

REQUIRED_COLUMNS = [
    "Symbol", "CompanyName", "Category", "SourceUrl",
    "OCRText", "OCRStatus", "ReviewStatus"
]

PROCESSED_COLUMNS = [
    # Original UiPath OCR columns
    "Symbol", "CompanyName", "Category", "SourceUrl",
    "OCRText", "OCRStatus", "ReviewStatus",

    # Python cleaned/validated columns
    "LatestPrice", "DailyChange", "PercentChange",
    "ValidationStatus", "ValidationReason",
    "MovementType", "AbsPercentChange",

    # Overall summary columns stored in same CSV
    "TotalRowsProcessed", "ValidRows", "NeedsReviewRows",
    "BiggestGainer", "BiggestGainerPercent",
    "BiggestDrop", "BiggestDropPercent",
    "BiggestMover", "BiggestMoverAbsPercent",
    "OverallWatchlistMood", "PythonProcessedAt"
]


def ensure_output_folder():
    os.makedirs("output", exist_ok=True)


def safe_text(value):
    if value is None:
        return ""
    return str(value).strip()


def to_float(value):
    """Convert number-looking text into float. Returns None if invalid."""
    if value is None:
        return None
    cleaned = str(value).strip()
    cleaned = cleaned.replace("$", "").replace(",", "")
    cleaned = cleaned.replace("−", "-").replace("+", "")
    cleaned = cleaned.replace("(", "").replace(")", "")
    try:
        return float(cleaned)
    except ValueError:
        return None


def normalise_ocr_text(text):
    text = safe_text(text)
    text = text.replace("\n", " ").replace("\r", " ")
    text = text.replace("−", "-")
    return re.sub(r"\s+", " ", text).strip()


def extract_stock_values(ocr_text):
    """
    Best-effort extraction from OCR text.
    Tries to find latest price, daily change, and percentage change.
    If OCR is unclear, missing fields stay as None and validation marks Needs Review.
    """
    text = normalise_ocr_text(ocr_text)

    # Best case example: 212.41 +1.52 (+0.72%)
    full_pattern = re.compile(
        r"(?P<price>\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s+"
        r"(?P<change>[+-]?\d+(?:\.\d+)?)\s+"
        r"\(?\s*(?P<percent>[+-]?\d+(?:\.\d+)?)\s*%\s*\)?"
    )
    match = full_pattern.search(text)
    if match:
        return {
            "latest_price": to_float(match.group("price")),
            "daily_change": to_float(match.group("change")),
            "percent_change": to_float(match.group("percent"))
        }

    # Fallback: find percentage anywhere.
    percent_change = None
    percent_match = re.search(r"([+-]?\d+(?:\.\d+)?)\s*%", text)
    if percent_match:
        percent_change = to_float(percent_match.group(1))

    # Fallback: find signed daily change before percentage.
    daily_change = None
    if percent_match:
        before_percent = text[:percent_match.start()]
        signed_numbers = re.findall(r"[+-]\s*\d+(?:\.\d+)?", before_percent)
        if signed_numbers:
            daily_change = to_float(signed_numbers[-1].replace(" ", ""))

    # Fallback: choose first positive number as price.
    text_without_percent = re.sub(r"[+-]?\d+(?:\.\d+)?\s*%", " ", text)
    number_candidates = re.findall(r"\d{1,3}(?:,\d{3})*(?:\.\d+)?", text_without_percent)
    latest_price = None
    for candidate in number_candidates:
        number = to_float(candidate)
        if number is not None and number > 0:
            latest_price = number
            break

    return {
        "latest_price": latest_price,
        "daily_change": daily_change,
        "percent_change": percent_change
    }


def validate_row(row, extracted):
    reasons = []

    ocr_status = safe_text(row.get("OCRStatus"))
    review_status = safe_text(row.get("ReviewStatus"))
    ocr_text = safe_text(row.get("OCRText"))

    if "failed" in ocr_status.lower():
        reasons.append("OCR status is failed")
    if "needs review" in review_status.lower():
        reasons.append("UiPath marked row as Needs Review")
    if not ocr_text:
        reasons.append("OCR text is empty")

    price = extracted["latest_price"]
    change = extracted["daily_change"]
    percent = extracted["percent_change"]

    if price is None:
        reasons.append("Latest price missing or wrong format")
    elif price <= 0:
        reasons.append("Latest price must be greater than 0")

    if change is None:
        reasons.append("Daily change missing or wrong format")

    if percent is None:
        reasons.append("Percentage change missing or wrong format")
    elif abs(percent) > 50:
        reasons.append("Percentage change is unusually large")

    if price is not None and change is not None and abs(change) > price:
        reasons.append("Daily change is larger than latest price")

    if reasons:
        return "Needs Review", ", ".join(reasons)
    return "Valid", "OK"


def movement_type(percent_change):
    if percent_change is None:
        return "Unknown"
    if percent_change > 0:
        return "Up"
    if percent_change < 0:
        return "Down"
    return "Flat"


def read_ocr_csv():
    if not os.path.exists(INPUT_CSV):
        raise FileNotFoundError(f"Input CSV not found: {INPUT_CSV}")

    with open(INPUT_CSV, "r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        rows = list(reader)
        actual_columns = reader.fieldnames or []

    # Add missing columns as blank instead of crashing row processing.
    for row in rows:
        for col in REQUIRED_COLUMNS:
            row.setdefault(col, "")

    missing_columns = [col for col in REQUIRED_COLUMNS if col not in actual_columns]
    return rows, missing_columns


def process_rows(rows):
    processed = []

    for row in rows:
        try:
            extracted = extract_stock_values(row.get("OCRText", ""))
            status, reason = validate_row(row, extracted)
            pct = extracted["percent_change"]

            processed.append({
                "Symbol": safe_text(row.get("Symbol")),
                "CompanyName": safe_text(row.get("CompanyName")),
                "Category": safe_text(row.get("Category")),
                "SourceUrl": safe_text(row.get("SourceUrl")),
                "OCRText": safe_text(row.get("OCRText")),
                "OCRStatus": safe_text(row.get("OCRStatus")),
                "ReviewStatus": safe_text(row.get("ReviewStatus")),
                "LatestPrice": "" if extracted["latest_price"] is None else round(extracted["latest_price"], 4),
                "DailyChange": "" if extracted["daily_change"] is None else round(extracted["daily_change"], 4),
                "PercentChange": "" if pct is None else round(pct, 4),
                "ValidationStatus": status,
                "ValidationReason": reason,
                "MovementType": movement_type(pct),
                "AbsPercentChange": "" if pct is None else round(abs(pct), 4),
            })
        except Exception as row_error:
            processed.append({
                "Symbol": safe_text(row.get("Symbol")),
                "CompanyName": safe_text(row.get("CompanyName")),
                "Category": safe_text(row.get("Category")),
                "SourceUrl": safe_text(row.get("SourceUrl")),
                "OCRText": safe_text(row.get("OCRText")),
                "OCRStatus": safe_text(row.get("OCRStatus")),
                "ReviewStatus": safe_text(row.get("ReviewStatus")),
                "LatestPrice": "",
                "DailyChange": "",
                "PercentChange": "",
                "ValidationStatus": "Needs Review",
                "ValidationReason": "Python row processing error: " + str(row_error),
                "MovementType": "Unknown",
                "AbsPercentChange": "",
            })

    return processed


def calculate_summary_values(processed):
    valid_rows = [row for row in processed if row["ValidationStatus"] == "Valid"]

    summary = {
        "TotalRowsProcessed": len(processed),
        "ValidRows": len(valid_rows),
        "NeedsReviewRows": len(processed) - len(valid_rows),
        "BiggestGainer": "",
        "BiggestGainerPercent": "",
        "BiggestDrop": "",
        "BiggestDropPercent": "",
        "BiggestMover": "",
        "BiggestMoverAbsPercent": "",
        "OverallWatchlistMood": "No valid stocks",
        "PythonProcessedAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    }

    if not valid_rows:
        return summary

    def pct_value(row):
        return float(row["PercentChange"])

    biggest_gainer = max(valid_rows, key=pct_value)
    biggest_drop = min(valid_rows, key=pct_value)
    biggest_mover = max(valid_rows, key=lambda row: abs(pct_value(row)))

    up_count = sum(1 for row in valid_rows if pct_value(row) > 0)
    down_count = sum(1 for row in valid_rows if pct_value(row) < 0)

    if up_count > down_count:
        mood = "Bullish / mostly up"
    elif down_count > up_count:
        mood = "Bearish / mostly down"
    else:
        mood = "Mixed"

    summary.update({
        "BiggestGainer": biggest_gainer["Symbol"],
        "BiggestGainerPercent": biggest_gainer["PercentChange"],
        "BiggestDrop": biggest_drop["Symbol"],
        "BiggestDropPercent": biggest_drop["PercentChange"],
        "BiggestMover": biggest_mover["Symbol"],
        "BiggestMoverAbsPercent": biggest_mover["AbsPercentChange"],
        "OverallWatchlistMood": mood,
    })

    return summary


def add_summary_to_rows(processed, summary):
    """
    Keep everything in one processed CSV.
    Summary fields are filled only in the first row to avoid repeated clutter.
    """
    for index, row in enumerate(processed):
        for key in summary:
            row[key] = summary[key] if index == 0 else ""
    return processed


def write_processed_csv(rows):
    with open(PROCESSED_CSV, "w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=PROCESSED_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def main():
    ensure_output_folder()
    rows, missing_columns = read_ocr_csv()
    processed = process_rows(rows)
    summary = calculate_summary_values(processed)

    if missing_columns:
        # Mark first row with missing input column info if possible.
        if processed:
            existing_reason = processed[0]["ValidationReason"]
            missing_reason = "Missing input columns added as blank: " + ", ".join(missing_columns)

            if existing_reason and existing_reason != "OK":
                processed[0]["ValidationReason"] = existing_reason + ", " + missing_reason
            else:
                processed[0]["ValidationReason"] = missing_reason

    processed_with_summary = add_summary_to_rows(processed, summary)
    write_processed_csv(processed_with_summary)

    print("AnalyseTS Python processing completed successfully.")
    print("Processed output saved to: " + PROCESSED_CSV)
    print("Valid rows: " + str(summary["ValidRows"]))
    print("Needs review rows: " + str(summary["NeedsReviewRows"]))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        ensure_output_folder()
        with open(ERROR_LOG_TXT, "w", encoding="utf-8") as file:
            file.write("AnalyseTS Python Processing Failed\n")
            file.write("Error: " + str(error) + "\n\n")
            file.write(traceback.format_exc())
        print("AnalyseTS Python processing failed. Check output/python_error_log.txt")
        raise
