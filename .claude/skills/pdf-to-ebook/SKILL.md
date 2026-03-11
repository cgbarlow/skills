---
name: pdf-to-ebook
description: Convert a PDF file to ebook formats (epub, mobi, azw3/Kindle) using Calibre. Use when the user wants to convert a PDF to an ebook format.
argument-hint: <input.pdf> [epub|mobi|azw3|all]
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash
---

# PDF to Ebook Converter

Convert a PDF to one or more ebook formats using Calibre's `ebook-convert`.

## Arguments

`$ARGUMENTS` — space-separated: first arg is the PDF path, optional second arg is the format(s).

- Format options: `epub`, `mobi`, `azw3`, `all`
- If no format is provided, **ask the user** which formats they want before proceeding.

## Workflow

### Step 1 — Parse arguments

Extract the PDF path from `$ARGUMENTS`. If a format argument is also present, use it. If not, ask:

> Which formats would you like to export?
> 1. epub
> 2. mobi
> 3. azw3 (Kindle, recommended over mobi)
> 4. all (epub + mobi + azw3)

Wait for the user's response before continuing.

### Step 2 — Validate inputs

1. Confirm the PDF file exists. If not, report the error and stop.
2. Check Calibre is installed:
   ```bash
   which ebook-convert
   ```
   If missing, tell the user to install it:
   - **Linux:** `sudo apt install calibre`
   - **macOS:** `brew install calibre`
   - Then stop.

### Step 3 — Check for scanned/image-only PDF (optional but recommended)

Run a quick text extraction check:
```bash
ebook-convert "<input.pdf>" /tmp/pdf_text_check.txt 2>/dev/null && wc -c /tmp/pdf_text_check.txt
```

If the output is fewer than 500 characters, the PDF is likely image-based (scanned). Warn the user:

> This PDF appears to be scanned or image-based and may convert poorly. Would you like to run OCR first using `ocrmypdf`?
> (Requires: `pip install ocrmypdf` and `tesseract`)

If they say yes:
```bash
ocrmypdf "<input.pdf>" "<input_ocr.pdf>"
```
Use the OCR'd file for all subsequent conversions.

### Step 4 — Convert

Derive the output base name from the input file (strip `.pdf` extension).

For each requested format, run:
```bash
ebook-convert "<input.pdf>" "<basename>.<format>" \
  --output-profile kindle_oasis \
  --enable-heuristics
```

Format-specific notes:
- **epub**: drop `--output-profile`; use `--output-profile tablet` instead
- **mobi**: use `--output-profile kindle`
- **azw3**: use `--output-profile kindle_oasis` (best Kindle compatibility)

Run conversions sequentially. Report each one as it completes.

### Step 5 — Report results

List each output file with its path and size:
```bash
ls -lh "<basename>.epub" "<basename>.mobi" "<basename>.azw3" 2>/dev/null
```

If any conversion failed, show the error output from `ebook-convert`.

## Example invocations

```
/pdf-to-ebook book.pdf
/pdf-to-ebook book.pdf epub
/pdf-to-ebook book.pdf all
/pdf-to-ebook /path/to/document.pdf azw3
```
