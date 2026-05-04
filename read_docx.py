import zipfile
import re
import xml.etree.ElementTree as ET
import os

docx_path = r"e:\projeck git\projek-pasal\Berkas berkas\LAPORAN1 (1).docx"

def read_docx(path):
    try:
        with zipfile.ZipFile(path) as z:
            xml_content = z.read('word/document.xml')
            tree = ET.fromstring(xml_content)
            
            # Extract paragraphs
            paragraphs = []
            # namespaces usually passed in xml, but we can search by local name or just iterate
            # simpler approach for raw text
            
            # The structure is usually body -> p -> r -> t
            # Let's iterate all elements and accumulate text
            
            # namespaces
            ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
            
            for p in tree.iter():
                # We want to capture paragraphs to output newlines
                if p.tag.endswith('}p'):
                   paragraphs.append('\n')
                if p.tag.endswith('}t'):
                   if p.text:
                       paragraphs.append(p.text)
            
            print("--- Content of DOCX ---")
            print("".join(paragraphs))
            
            # List images
            images = [f for f in z.namelist() if f.startswith('word/media/')]
            print("\n--- List of Images ---")
            for img in images:
                print(img)
                
    except Exception as e:
        print(f"Error reading docx: {e}")

if __name__ == "__main__":
    if os.path.exists(docx_path):
        read_docx(docx_path)
    else:
        print(f"File not found: {docx_path}")
