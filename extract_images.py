import zipfile
import os

docx_path = r"e:\projeck git\projek-pasal\Berkas berkas\LAPORAN1 (1).docx"
extract_dir = r"e:\projeck git\projek-pasal\extracted_images"

if not os.path.exists(extract_dir):
    os.makedirs(extract_dir)

def extract_images(docx_path, output_dir):
    try:
        with zipfile.ZipFile(docx_path) as z:
            file_list = z.namelist()
            media_files = [f for f in file_list if f.startswith('word/media/')]
            
            for media_file in media_files:
                filename = os.path.basename(media_file)
                target_path = os.path.join(output_dir, filename)
                with open(target_path, "wb") as f_out:
                    f_out.write(z.read(media_file))
                print(f"Extracted: {filename}")
                
    except Exception as e:
        print(f"Error extracting images: {e}")

if __name__ == "__main__":
    if os.path.exists(docx_path):
        extract_images(docx_path, extract_dir)
    else:
        print(f"File not found: {docx_path}")
