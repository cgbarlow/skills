# ebook-creator

A Claude Code skill for converting PDF files to ebook formats using [Calibre](https://calibre-ebook.com/).

## Features

- Converts PDFs to **epub**, **mobi**, and **azw3** (Kindle) formats
- Detects scanned/image-based PDFs and offers OCR via `ocrmypdf`
- Applies format-specific output profiles for best compatibility

## Requirements

- [Calibre](https://calibre-ebook.com/) (`ebook-convert`)
  - Linux: `sudo apt install calibre`
  - macOS: `brew install calibre`
- (Optional) OCR support: `pip install ocrmypdf` + `tesseract`

## Usage

In Claude Code, use the `/pdf-to-ebook` slash command:

```
/pdf-to-ebook <input.pdf> [epub|mobi|azw3|all]
```

If no format is specified, Claude will ask which formats you want.

### Examples

```
/pdf-to-ebook book.pdf
/pdf-to-ebook book.pdf epub
/pdf-to-ebook book.pdf azw3
/pdf-to-ebook /path/to/document.pdf all
```

## Output

Converted files are written to the same directory as the input PDF, with the same base name and the appropriate extension (e.g. `book.epub`, `book.azw3`).
