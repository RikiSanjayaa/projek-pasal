from pypdf import PdfReader
import os

pdf_path = r"e:\projeck git\projek-pasal\Berkas berkas\Deskripsi HKI Sipadir (1) - Sentra HKI.pdf"

if os.path.exists(pdf_path):
    try:
        reader = PdfReader(pdf_path)
        print(f"--- Information ---")
        print(f"Number of Pages: {len(reader.pages)}")
        print(f"--- Text Content ---")
        for i, page in enumerate(reader.pages):
            print(f"--- Page {i+1} ---")
            print(page.extract_text())
    except Exception as e:
        print(f"Error reading PDF: {e}")
else:
    print(f"File not found: {pdf_path}")
