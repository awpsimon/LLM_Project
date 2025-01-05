from spire.pdf import *

def pdf_to_html(filepath):

    # Create a Document object
    doc = PdfDocument()

    # Load PDF
    doc.LoadFromFile(filepath)

    # Specify convert options (Convert a PDF to an HTML File with SVG Embedded)
    doc.ConvertOptions.SetPdfToHtmlOptions(True, True, 1, True)

    # Save the PDF document to HTML format
    filepath = filepath.replace(".pdf", ".html")
    doc.SaveToFile(filepath, FileFormat.HTML)

    # Dispose resources
    doc.Dispose()

    return filepath
