import { cp, mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const dist = new URL('./dist/', import.meta.url);
await mkdir(dist, { recursive: true });
for (const name of ['index.html', 'styles.css', 'app.js', 'manifest.webmanifest', 'assets']) {
  await cp(new URL(`./${name}`, import.meta.url), new URL(`./dist/${name}`, import.meta.url), { recursive: true });
}
for (const name of ['pdf.mjs', 'pdf.worker.mjs']) {
  await cp(new URL(`./node_modules/pdfjs-dist/build/${name}`, import.meta.url), new URL(`./dist/assets/${name}`, import.meta.url));
}
await cp(new URL('./node_modules/pdfjs-dist/LICENSE', import.meta.url), new URL('./dist/assets/pdfjs-LICENSE', import.meta.url));

// An original, clearly labeled document lets the reader be demonstrated without
// presenting an invented publication as an official ROCKS issue.
const content = 'BT /F1 22 Tf 55 720 Td (ROCKS Connect Demo) Tj 0 -35 Td /F1 12 Tf (Sample document - not an official publication.) Tj 0 -24 Td (This document demonstrates the PDF reading experience.) Tj ET';
const objects = [
  '<< /Type /Catalog /Pages 2 0 R >>',
  '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
  '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
  '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  `<< /Length ${Buffer.byteLength(content)} >>\nstream\n${content}\nendstream`
];
let pdf = '%PDF-1.4\n';
const offsets = [0];
objects.forEach((object, index) => {
  offsets.push(Buffer.byteLength(pdf));
  pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
});
const xref = Buffer.byteLength(pdf);
pdf += `xref\n0 ${offsets.length}\n0000000000 65535 f \n`;
pdf += offsets.slice(1).map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('');
pdf += `trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
await writeFile(join(fileURLToPath(dist), 'assets', 'sample-demo.pdf'), pdf);
console.log('Production demo built in dist/.');
