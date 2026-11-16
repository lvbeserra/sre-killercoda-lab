"""Gera PDF ficticio minimo, sem dependencia externa e sem dados pessoais."""
import sys
from pathlib import Path

target = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/curriculo-ficticio.pdf")
stream = b"BT /F1 18 Tf 72 720 Td (Curriculo ficticio SRE - Aula 02) Tj ET"
objects = [
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
    b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream",
]
pdf = bytearray(b"%PDF-1.4\n")
offsets = [0]
for index, obj in enumerate(objects, start=1):
    offsets.append(len(pdf))
    pdf.extend(str(index).encode() + b" 0 obj\n" + obj + b"\nendobj\n")
xref = len(pdf)
pdf.extend(b"xref\n0 6\n0000000000 65535 f \n")
for offset in offsets[1:]:
    pdf.extend(f"{offset:010d} 00000 n \n".encode())
pdf.extend(b"trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n")
pdf.extend(str(xref).encode() + b"\n%%EOF\n")
target.write_bytes(pdf)
print(f"PDF ficticio criado: {target} ({len(pdf)} bytes)")
