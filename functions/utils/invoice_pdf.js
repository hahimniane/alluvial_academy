'use strict';

const PAGE_WIDTH = 612;
const PAGE_HEIGHT = 792;
const MARGIN = 40;

const COMPANY_INFO = {
  name: 'Alluwal Education Hub',
  fullAddress: 'Lacey, Lacey, Washington State, United States of America',
  phone: '+1646-338-1286',
  email: 'alluwhalacademy@gmail.com',
};

const ADMIN_INFO = {
  name: 'Muhammed Barry',
};

const _toText = (value) =>
  String(value ?? '')
    .replace(/[^\x09\x0A\x0D\x20-\x7E]/g, '')
    .trim();

const _escapePdfText = (value) =>
  _toText(value).replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');

const _toNumber = (value) => {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const _toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const _formatDateLong = (value) => {
  const date = _toDate(value);
  if (!date) return '';
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
};

const _formatMonth = (value) => {
  const date = _toDate(value);
  if (!date) return '';
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
  });
};

const _displayBillingPeriod = (invoice) => {
  const raw = _toText(invoice.displayBillingPeriod || invoice.billing_period || invoice.billingPeriod || invoice.period);
  const parts = raw.split('-');
  if (parts.length >= 2) {
    const year = Number(parts[0]);
    const month = Number(parts[1]);
    if (Number.isInteger(year) && Number.isInteger(month) && month >= 1 && month <= 12) {
      return _formatMonth(new Date(Date.UTC(year, month - 1, 1)));
    }
  }
  return raw || _formatMonth(invoice.issued_date || invoice.issuedDate);
};

const _money = (amount, currency) => {
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: (currency || 'USD').toString().toUpperCase(),
    }).format(_toNumber(amount));
  } catch (error) {
    return `${currency || 'USD'} ${_toNumber(amount).toFixed(2)}`;
  }
};

const _wrapText = (value, maxChars) => {
  const words = _toText(value).split(/\s+/).filter(Boolean);
  const lines = [];
  let current = '';

  for (const word of words) {
    const next = current ? `${current} ${word}` : word;
    if (next.length > maxChars && current) {
      lines.push(current);
      current = word;
    } else {
      current = next;
    }
  }

  if (current) lines.push(current);
  return lines.length ? lines : [''];
};

class PdfCanvas {
  constructor() {
    this.ops = [];
  }

  color(hex) {
    const normalized = hex.replace('#', '');
    const r = parseInt(normalized.slice(0, 2), 16) / 255;
    const g = parseInt(normalized.slice(2, 4), 16) / 255;
    const b = parseInt(normalized.slice(4, 6), 16) / 255;
    return `${r.toFixed(3)} ${g.toFixed(3)} ${b.toFixed(3)}`;
  }

  fillRect(x, y, width, height, color) {
    this.ops.push(`${this.color(color)} rg ${x} ${y} ${width} ${height} re f`);
  }

  strokeRect(x, y, width, height, color, lineWidth = 1) {
    this.ops.push(`${lineWidth} w ${this.color(color)} RG ${x} ${y} ${width} ${height} re S`);
  }

  line(x1, y1, x2, y2, color, lineWidth = 1) {
    this.ops.push(`${lineWidth} w ${this.color(color)} RG ${x1} ${y1} m ${x2} ${y2} l S`);
  }

  text(x, y, text, {size = 11, color = '#111827', bold = false} = {}) {
    const font = bold ? 'F2' : 'F1';
    this.ops.push(`${this.color(color)} rg BT /${font} ${size} Tf ${x} ${y} Td (${_escapePdfText(text)}) Tj ET`);
  }

  wrappedText(x, y, text, {size = 11, color = '#111827', bold = false, maxChars = 70, lineHeight = 14} = {}) {
    const lines = _wrapText(text, maxChars);
    lines.forEach((line, index) => {
      this.text(x, y - index * lineHeight, line, {size, color, bold});
    });
    return lines.length * lineHeight;
  }

  content() {
    return this.ops.join('\n');
  }
}

const _drawHeader = (canvas, y) => {
  canvas.fillRect(MARGIN, y - 88, 5, 88, '#1d4ed8');
  canvas.fillRect(MARGIN + 19, y - 64, 64, 64, '#dbeafe');
  canvas.strokeRect(MARGIN + 19, y - 64, 64, 64, '#3b82f6', 1.5);
  canvas.text(MARGIN + 34, y - 39, 'AEH', {size: 20, color: '#1d4ed8', bold: true});

  const x = MARGIN + 99;
  canvas.text(x, y - 16, COMPANY_INFO.name, {size: 22, bold: true});
  canvas.text(x, y - 38, COMPANY_INFO.fullAddress, {size: 11, color: '#4b5563'});
  canvas.text(x, y - 56, `Contact: ${COMPANY_INFO.phone}`, {size: 11, color: '#4b5563'});
  canvas.text(x, y - 72, `Email: ${COMPANY_INFO.email}`, {size: 11, color: '#4b5563'});
};

const _drawInvoiceTitle = (canvas, y, invoiceNumber) => {
  const height = 70;
  canvas.fillRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#dbeafe');
  canvas.strokeRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#bfdbfe', 1);
  canvas.fillRect(MARGIN, y - height, 5, height, '#1d4ed8');
  canvas.text(MARGIN + 21, y - 22, 'INVOICE', {size: 11, color: '#1d4ed8', bold: true});
  canvas.text(MARGIN + 21, y - 46, 'Tuition & fees', {size: 17, bold: true});
  if (invoiceNumber) {
    canvas.text(MARGIN + 21, y - 64, invoiceNumber, {size: 12, color: '#374151', bold: true});
  }
};

const _drawInfoBox = (canvas, y, rows) => {
  const visibleRows = rows.filter((row) => row.value);
  const height = 32 + visibleRows.length * 24;
  canvas.fillRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#f3f4f6');
  canvas.strokeRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#d1d5db');
  let rowY = y - 28;
  visibleRows.forEach((row) => {
    canvas.text(MARGIN + 16, rowY, row.label, {size: 12, color: '#4b5563', bold: true});
    canvas.text(MARGIN + 136, rowY, row.value, {size: 12, bold: true});
    rowY -= 24;
  });
  return height;
};

const _drawPayerBox = (canvas, y, parentName, studentName, billingPeriod) => {
  const height = 62;
  canvas.fillRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#f3f4f6');
  canvas.strokeRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#d1d5db');
  canvas.text(MARGIN + 16, y - 24, `From: ${parentName}  |  Student: ${studentName}`, {
    size: 13,
    bold: true,
  });
  canvas.text(MARGIN + 16, y - 46, `Billing period: ${billingPeriod}`, {size: 12, color: '#4b5563'});
  return height;
};

const _drawTable = (canvas, y, items, currency) => {
  const rows = Array.isArray(items) ? items : [];
  if (rows.length === 0) {
    const height = 58;
    canvas.fillRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#f3f4f6');
    canvas.strokeRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#d1d5db');
    canvas.text(MARGIN + 200, y - 34, 'No items on this invoice', {size: 12, color: '#4b5563'});
    return height;
  }

  const widths = [248, 58, 113, 113];
  const rowHeight = 30;
  const x0 = MARGIN;
  const height = rowHeight * (rows.length + 1);

  canvas.fillRect(x0, y - rowHeight, PAGE_WIDTH - MARGIN * 2, rowHeight, '#1d4ed8');
  canvas.strokeRect(x0, y - height, PAGE_WIDTH - MARGIN * 2, height, '#d1d5db');

  let x = x0;
  ['Description', 'Qty', 'Price', 'Total'].forEach((label, index) => {
    canvas.text(x + 8, y - 20, label, {size: 11, color: '#ffffff', bold: true});
    x += widths[index];
  });

  rows.forEach((item, index) => {
    const rowTop = y - rowHeight * (index + 1);
    canvas.line(x0, rowTop - rowHeight, PAGE_WIDTH - MARGIN, rowTop - rowHeight, '#d1d5db');
    x = x0;
    const unitPrice = _toNumber(item.unit_price ?? item.unitPrice);
    const total = _toNumber(item.total);
    const values = [
      _toText(item.description || `Item ${index + 1}`),
      String(_toNumber(item.quantity) || 1),
      _money(unitPrice, currency),
      _money(total, currency),
    ];
    values.forEach((value, column) => {
      canvas.text(x + 8, rowTop - 20, value, {
        size: 10,
        bold: column === 3,
      });
      x += widths[column];
      if (column < widths.length - 1) {
        canvas.line(x, rowTop, x, rowTop - rowHeight, '#d1d5db');
      }
    });
  });

  return height;
};

const _drawSummary = (canvas, y, invoice, currency) => {
  const totalAmount = _toNumber(invoice.total_amount ?? invoice.totalAmount);
  const paidAmount = _toNumber(invoice.paid_amount ?? invoice.paidAmount);
  const remaining = Math.max(0, totalAmount - paidAmount);
  const height = 112;
  const boxWidth = PAGE_WIDTH - MARGIN * 2;
  canvas.fillRect(MARGIN, y - height, boxWidth, height, '#f3f4f6');
  canvas.strokeRect(MARGIN, y - height, boxWidth, height, '#d1d5db');

  const rows = [
    ['Subtotal', _money(totalAmount, currency), false],
    ['Paid', _money(paidAmount, currency), false],
    ['Remaining Balance', _money(remaining, currency), true],
  ];

  let rowY = y - 26;
  rows.forEach(([label, value, isTotal], index) => {
    if (index === 2) canvas.line(MARGIN + 16, rowY + 14, PAGE_WIDTH - MARGIN - 16, rowY + 14, '#d1d5db');
    canvas.text(MARGIN + 16, rowY, label, {size: isTotal ? 14 : 12, bold: true});
    canvas.text(PAGE_WIDTH - MARGIN - 125, rowY, value, {
      size: isTotal ? 16 : 12,
      color: isTotal ? '#1d4ed8' : '#111827',
      bold: true,
    });
    rowY -= index === 1 ? 38 : 26;
  });

  return height;
};

const _drawFooter = (canvas, y) => {
  const height = 76;
  canvas.fillRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#f3f4f6');
  canvas.strokeRect(MARGIN, y - height, PAGE_WIDTH - MARGIN * 2, height, '#d1d5db');
  canvas.text(MARGIN + 16, y - 24, `Received by: ${ADMIN_INFO.name}`, {size: 12, bold: true});
  canvas.text(MARGIN + 16, y - 55, 'Signature', {size: 12, color: '#4b5563', bold: true});
  canvas.line(MARGIN + 92, y - 56, PAGE_WIDTH - MARGIN - 16, y - 56, '#111827');
  return height;
};

const _buildContent = (invoice) => {
  const canvas = new PdfCanvas();
  const currency = _toText(invoice.currency || 'USD') || 'USD';
  const invoiceNumber = _toText(invoice.invoiceNumber || invoice.invoice_number || invoice.id);
  const issuedDate = invoice.issuedDate || invoice.issued_date || invoice.createdAt || invoice.created_at || new Date();
  const dueDate = invoice.dueDate || invoice.due_date;
  const accessCutoffDate = invoice.accessCutoffDate || invoice.access_cutoff_date;
  const billingPeriod = _displayBillingPeriod(invoice);
  const parentName = _toText(invoice.parentName) || 'Parent';
  const studentName = _toText(invoice.studentName || invoice.studentId || invoice.student_id);

  let y = PAGE_HEIGHT - MARGIN;
  _drawHeader(canvas, y);
  y -= 116;
  _drawInvoiceTitle(canvas, y, invoiceNumber);
  y -= 92;
  y -= _drawInfoBox(canvas, y, [
    {label: 'Invoice Number', value: invoiceNumber},
    {label: 'Payment Date', value: _formatDateLong(issuedDate)},
    {label: 'Due Date', value: _formatDateLong(dueDate)},
    {label: 'Access cutoff', value: _formatDateLong(accessCutoffDate)},
    {label: 'Billing period', value: billingPeriod},
  ]) + 22;

  if (parentName || studentName) {
    y -= _drawPayerBox(canvas, y, parentName, studentName || _toText(invoice.student_id), billingPeriod) + 24;
  }

  y -= _drawTable(canvas, y, invoice.items, currency) + 24;
  y -= _drawSummary(canvas, y, invoice, currency) + 32;
  _drawFooter(canvas, Math.max(y, 116));

  return canvas.content();
};

const _buildPdf = (content) => {
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
    `<< /Length ${Buffer.byteLength(content, 'utf8')} >>\nstream\n${content}\nendstream`,
  ];

  let pdf = '%PDF-1.4\n';
  const offsets = [0];
  objects.forEach((object, index) => {
    offsets.push(Buffer.byteLength(pdf, 'utf8'));
    pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });

  const xrefOffset = Buffer.byteLength(pdf, 'utf8');
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += '0000000000 65535 f \n';
  for (let i = 1; i < offsets.length; i += 1) {
    pdf += `${String(offsets[i]).padStart(10, '0')} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;

  return Buffer.from(pdf, 'utf8');
};

const generateInvoicePdfBuffer = (invoice) => _buildPdf(_buildContent(invoice));

module.exports = {
  generateInvoicePdfBuffer,
};
