/**
 * The invoice PDF a parent prints from the invoice page (inventory B-045…B-056),
 * built in the browser with no library: a port of the dependency-free writer in
 * functions/utils/invoice_pdf.js (the emailed copy), with the Flutter app's
 * rules for what appears (lib/features/parent/services/invoice_pdf_service.dart):
 *
 *   - A4, 40 pt margins, Helvetica, one page, English only.
 *   - "Payment Date" is the ISSUE date and the payer box says "From:" — kept
 *     word for word (plan default: PDF wording same as today).
 *   - "Access cutoff" only when the invoice has an explicit cut-off date;
 *     "Billing period" only when the invoice has a period; the payer box only
 *     when a parent or student name was found ("Parent" / the student id as
 *     fall-backs) and its period line falls back to the issue month.
 *
 * Unlike the server copy, accented Latin letters (é, ï, ç…) are kept: the
 * fonts use WinAnsi encoding and the file is written byte for byte.
 */
import type { ParentInvoice } from "./parentHome.ts";
import { billingPeriod } from "./parentHome.ts";

const PAGE_WIDTH = 595.28;
const PAGE_HEIGHT = 841.89;
const MARGIN = 40;
const INNER = PAGE_WIDTH - MARGIN * 2;

export const COMPANY_INFO = {
  name: "Alluwal Education Hub",
  fullAddress: "11 McKeever Pl, Brooklyn, NY 11225, United States",
  phone: "+1646-338-1286",
  email: "billing@alluwaleducationhub.org",
};
const ADMIN_NAME = "Muhammed Barry";

/** Text a WinAnsi Type1 font can draw: Latin-1 kept, everything else dropped. */
function pdfText(value: unknown) {
  return String(value ?? "")
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[–—]/g, "-")
    .replace(/[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]/g, "")
    .trim();
}

const escape = (value: unknown) => pdfText(value).replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");

const num = (n: number) => (Number.isInteger(n) ? String(n) : n.toFixed(2));

function money(amount: number, currency: string) {
  try {
    return new Intl.NumberFormat("en-US", { style: "currency", currency: (currency || "USD").toUpperCase() }).format(amount);
  } catch {
    return `${currency || "USD"} ${amount.toFixed(2)}`;
  }
}

/** DateFormat.yMMMMd → "November 1, 2026". */
const longDate = (date: Date) => date.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" });
/** DateFormat.yMMMM → "November 2026". */
const longMonth = (date: Date) => date.toLocaleDateString("en-US", { year: "numeric", month: "long" });

/** Split text so each line holds at most `maxChars` characters (words kept whole when possible). */
export function wrapText(value: string, maxChars: number): string[] {
  const words = pdfText(value).split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let current = "";
  for (const word of words) {
    const chunks = word.length > maxChars ? word.match(new RegExp(`.{1,${maxChars}}`, "g")) ?? [word] : [word];
    for (const chunk of chunks) {
      const next = current ? `${current} ${chunk}` : chunk;
      if (next.length > maxChars && current) {
        lines.push(current);
        current = chunk;
      } else {
        current = next;
      }
    }
  }
  if (current) lines.push(current);
  return lines.length ? lines : [""];
}

class Canvas {
  ops: string[] = [];
  private rgb(hex: string) {
    const h = hex.replace("#", "");
    return [0, 2, 4].map((i) => (Number.parseInt(h.slice(i, i + 2), 16) / 255).toFixed(3)).join(" ");
  }
  fillRect(x: number, y: number, w: number, h: number, color: string) {
    this.ops.push(`${this.rgb(color)} rg ${num(x)} ${num(y)} ${num(w)} ${num(h)} re f`);
  }
  strokeRect(x: number, y: number, w: number, h: number, color: string, width = 1) {
    this.ops.push(`${width} w ${this.rgb(color)} RG ${num(x)} ${num(y)} ${num(w)} ${num(h)} re S`);
  }
  line(x1: number, y1: number, x2: number, y2: number, color: string, width = 1) {
    this.ops.push(`${width} w ${this.rgb(color)} RG ${num(x1)} ${num(y1)} m ${num(x2)} ${num(y2)} l S`);
  }
  text(x: number, y: number, value: string, { size = 11, color = "#111827", bold = false } = {}) {
    this.ops.push(`${this.rgb(color)} rg BT /${bold ? "F2" : "F1"} ${size} Tf ${num(x)} ${num(y)} Td (${escape(value)}) Tj ET`);
  }
}

export type InvoicePdfInput = {
  invoice: ParentInvoice;
  parentName: string | null;
  studentName: string | null;
};

function drawHeader(c: Canvas, y: number) {
  c.fillRect(MARGIN, y - 88, 5, 88, "#1d4ed8");
  c.fillRect(MARGIN + 19, y - 64, 64, 64, "#dbeafe");
  c.strokeRect(MARGIN + 19, y - 64, 64, 64, "#3b82f6", 1.5);
  c.text(MARGIN + 34, y - 39, "AEH", { size: 20, color: "#1d4ed8", bold: true });
  const x = MARGIN + 99;
  c.text(x, y - 16, COMPANY_INFO.name, { size: 22, bold: true });
  c.text(x, y - 38, COMPANY_INFO.fullAddress, { size: 11, color: "#4b5563" });
  c.text(x, y - 56, `Contact: ${COMPANY_INFO.phone}`, { size: 11, color: "#4b5563" });
  c.text(x, y - 72, `Email: ${COMPANY_INFO.email}`, { size: 11, color: "#4b5563" });
}

function drawTitle(c: Canvas, y: number, invoiceNumber: string) {
  const h = 70;
  c.fillRect(MARGIN, y - h, INNER, h, "#dbeafe");
  c.strokeRect(MARGIN, y - h, INNER, h, "#bfdbfe", 1);
  c.fillRect(MARGIN, y - h, 5, h, "#1d4ed8");
  c.text(MARGIN + 21, y - 22, "INVOICE", { size: 11, color: "#1d4ed8", bold: true });
  c.text(MARGIN + 21, y - 46, "Tuition & fees", { size: 17, bold: true });
  c.text(MARGIN + 21, y - 64, invoiceNumber, { size: 12, color: "#374151", bold: true });
}

function drawInfo(c: Canvas, y: number, rows: Array<[string, string]>) {
  const h = 32 + rows.length * 24;
  c.fillRect(MARGIN, y - h, INNER, h, "#f3f4f6");
  c.strokeRect(MARGIN, y - h, INNER, h, "#d1d5db");
  let rowY = y - 28;
  for (const [label, value] of rows) {
    c.text(MARGIN + 16, rowY, label, { size: 12, color: "#4b5563", bold: true });
    c.text(MARGIN + 136, rowY, value, { size: 12, bold: true });
    rowY -= 24;
  }
  return h;
}

function drawPayer(c: Canvas, y: number, parent: string, student: string, period: string) {
  const h = 62;
  c.fillRect(MARGIN, y - h, INNER, h, "#f3f4f6");
  c.strokeRect(MARGIN, y - h, INNER, h, "#d1d5db");
  c.text(MARGIN + 16, y - 24, `From: ${parent}  |  Student: ${student}`, { size: 13, bold: true });
  c.text(MARGIN + 16, y - 46, `Billing period: ${period}`, { size: 12, color: "#4b5563" });
  return h;
}

function drawItems(c: Canvas, y: number, invoice: ParentInvoice) {
  if (invoice.items.length === 0) {
    const h = 58;
    c.fillRect(MARGIN, y - h, INNER, h, "#f3f4f6");
    c.strokeRect(MARGIN, y - h, INNER, h, "#d1d5db");
    c.text(MARGIN + INNER / 2 - 66, y - 34, "No items on this invoice", { size: 12, color: "#4b5563" });
    return h;
  }
  const widths = [INNER * 0.47, INNER * 0.11, INNER * 0.21, INNER * 0.21];
  const head = 30;
  const lineHeight = 13;
  const rows = invoice.items.map((item) => wrapText(item.description, 44));
  const rowHeights = rows.map((lines) => Math.max(30, 17 + lines.length * lineHeight));
  const h = head + rowHeights.reduce((a, b) => a + b, 0);
  c.fillRect(MARGIN, y - head, INNER, head, "#1d4ed8");
  c.strokeRect(MARGIN, y - h, INNER, h, "#d1d5db");
  let x = MARGIN;
  ["Description", "Qty", "Price", "Total"].forEach((label, i) => {
    c.text(x + 8, y - 20, label, { size: 11, color: "#ffffff", bold: true });
    x += widths[i];
  });
  let top = y - head;
  invoice.items.forEach((item, index) => {
    const rh = rowHeights[index];
    c.line(MARGIN, top - rh, MARGIN + INNER, top - rh, "#d1d5db");
    const cells = [String(item.quantity), money(item.unitPrice, invoice.currency), money(item.total, invoice.currency)];
    rows[index].forEach((line, i) => c.text(MARGIN + 8, top - 20 - i * lineHeight, line, { size: 10 }));
    x = MARGIN + widths[0];
    c.line(x, top, x, top - rh, "#d1d5db");
    cells.forEach((value, i) => {
      c.text(x + 8, top - 20, value, { size: 10, bold: i === 2 });
      x += widths[i + 1];
      if (i < 2) c.line(x, top, x, top - rh, "#d1d5db");
    });
    top -= rh;
  });
  return h;
}

function drawSummary(c: Canvas, y: number, invoice: ParentInvoice) {
  const remaining = Math.max(0, invoice.totalAmount - invoice.paidAmount);
  const h = 112;
  c.fillRect(MARGIN, y - h, INNER, h, "#f3f4f6");
  c.strokeRect(MARGIN, y - h, INNER, h, "#d1d5db");
  const rows: Array<[string, string, boolean]> = [
    ["Subtotal", money(invoice.totalAmount, invoice.currency), false],
    ["Paid", money(invoice.paidAmount, invoice.currency), false],
    ["Remaining Balance", money(remaining, invoice.currency), true],
  ];
  let rowY = y - 26;
  rows.forEach(([label, value, total], index) => {
    if (index === 2) c.line(MARGIN + 16, rowY + 14, PAGE_WIDTH - MARGIN - 16, rowY + 14, "#d1d5db");
    c.text(MARGIN + 16, rowY, label, { size: total ? 14 : 12, bold: true });
    c.text(PAGE_WIDTH - MARGIN - 125, rowY, value, { size: total ? 16 : 12, color: total ? "#1d4ed8" : "#111827", bold: true });
    rowY -= index === 1 ? 38 : 26;
  });
  return h;
}

function drawFooter(c: Canvas, y: number) {
  const h = 76;
  c.fillRect(MARGIN, y - h, INNER, h, "#f3f4f6");
  c.strokeRect(MARGIN, y - h, INNER, h, "#d1d5db");
  c.text(MARGIN + 16, y - 24, `Received by: ${ADMIN_NAME}`, { size: 12, bold: true });
  c.text(MARGIN + 16, y - 55, "Signature", { size: 12, color: "#4b5563", bold: true });
  c.line(MARGIN + 92, y - 56, PAGE_WIDTH - MARGIN - 16, y - 56, "#111827");
}

type Block = { height: number; gap: number; draw: (c: Canvas, y: number) => void };

/**
 * Each page's drawing operators. Blocks are laid out top to bottom; one that
 * would cross the bottom margin starts a new page (Flutter's single-page
 * layout cannot fit long invoices at all).
 */
export function invoicePdfPages({ invoice, parentName, studentName }: InvoicePdfInput): string[] {
  const number = invoice.invoiceNumber || invoice.id;
  const period = billingPeriod(invoice);
  const rows: Array<[string, string]> = [
    ["Invoice Number", number],
    ["Payment Date", longDate(invoice.issuedDate)],
    ["Due Date", longDate(invoice.dueDate)],
  ];
  if (invoice.accessCutoffDate) rows.push(["Access cutoff", longDate(invoice.accessCutoffDate)]);
  if (period) rows.push(["Billing period", period]);

  const probe = new Canvas();
  const blocks: Block[] = [
    { height: 88, gap: 28, draw: (c, y) => drawHeader(c, y) },
    { height: 70, gap: 22, draw: (c, y) => drawTitle(c, y, number) },
    { height: 32 + rows.length * 24, gap: 22, draw: (c, y) => void drawInfo(c, y, rows) },
  ];
  if (parentName !== null || studentName !== null) {
    blocks.push({ height: 62, gap: 24, draw: (c, y) => void drawPayer(c, y, parentName ?? "Parent", studentName ?? invoice.studentId, period ?? longMonth(invoice.issuedDate)) });
  }
  blocks.push({ height: drawItems(probe, PAGE_HEIGHT, invoice), gap: 24, draw: (c, y) => void drawItems(c, y, invoice) });
  blocks.push({ height: 112, gap: 32, draw: (c, y) => void drawSummary(c, y, invoice) });
  blocks.push({ height: 76, gap: 0, draw: (c, y) => drawFooter(c, y) });

  const pages: Canvas[] = [new Canvas()];
  let y = PAGE_HEIGHT - MARGIN;
  for (const block of blocks) {
    if (y - block.height < MARGIN && pages[pages.length - 1].ops.length > 0) {
      pages.push(new Canvas());
      y = PAGE_HEIGHT - MARGIN;
    }
    block.draw(pages[pages.length - 1], y);
    y -= block.height + block.gap;
  }
  return pages.map((page) => page.ops.join("\n"));
}

/** All pages' operators in one string (for tests). */
export function invoicePdfContent(input: InvoicePdfInput): string {
  return invoicePdfPages(input).join("\n");
}

/** The whole file as bytes (Latin-1, one byte per character). */
export function invoicePdfBytes(input: InvoicePdfInput): Uint8Array {
  const pages = invoicePdfPages(input);
  const font = (name: string) => `<< /Type /Font /Subtype /Type1 /BaseFont /${name} /Encoding /WinAnsiEncoding >>`;
  // 1 catalog, 2 pages, 3 + 4 fonts, then a page object and a content stream per page.
  const pageIds = pages.map((_, i) => 5 + i * 2);
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    `<< /Type /Pages /Kids [${pageIds.map((id) => `${id} 0 R`).join(" ")}] /Count ${pages.length} >>`,
    font("Helvetica"),
    font("Helvetica-Bold"),
  ];
  pages.forEach((content, i) => {
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${PAGE_WIDTH} ${PAGE_HEIGHT}] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents ${pageIds[i] + 1} 0 R >>`);
    objects.push(`<< /Length ${content.length} >>\nstream\n${content}\nendstream`);
  });
  let pdf = "%PDF-1.4\n";
  const offsets: number[] = [];
  objects.forEach((object, index) => {
    offsets.push(pdf.length);
    pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const offset of offsets) pdf += `${String(offset).padStart(10, "0")} 00000 n \n`;
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  const bytes = new Uint8Array(pdf.length);
  for (let i = 0; i < pdf.length; i += 1) bytes[i] = pdf.charCodeAt(i) & 0xff;
  return bytes;
}
