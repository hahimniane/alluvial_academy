'use strict';

const HELVETICA = [278,278,355,556,556,889,667,191,333,333,389,584,278,333,278,278,556,556,556,556,556,556,556,556,556,556,278,278,584,584,584,556,1015,667,667,722,722,667,611,778,722,278,500,667,556,833,722,778,667,778,722,667,611,722,667,944,667,667,611,278,278,277,469,556,333,556,556,500,556,556,278,556,556,222,222,500,222,833,556,556,556,556,333,500,278,556,500,722,500,500,500,334,260,334,584,500,655,500,222,278,333,1000,556,556,333,1000,667,250,1000,500,611,500,500,222,221,333,333,350,556,1000,333,1000,500,250,938,500,500,667,278,278,556,556,556,556,260,556,333,737,370,448,584,333,737,333,606,584,350,350,333,556,537,278,333,350,365,448,869,869,879,556,667,667,667,667,667,667,1000,722,667,667,667,667,278,278,278,278,722,722,778,778,778,778,778,584,778,722,722,722,722,667,666,611,556,556,556,556,556,556,896,500,556,556,556,556,251,251,251,251,556,556,556,556,556,556,556,584,611,556,556,556,556,500,555,500];
const HELVETICA_BOLD = [278,333,474,556,556,889,722,238,333,333,389,584,278,333,278,278,556,556,556,556,556,556,556,556,556,556,333,333,584,584,584,611,975,722,722,722,722,667,611,778,722,278,556,722,611,833,722,778,667,778,722,667,611,722,667,944,667,667,611,333,278,333,584,556,333,556,611,556,611,556,333,611,611,278,278,556,278,889,611,611,611,611,389,556,333,611,556,778,556,556,500,389,280,389,584,350,556,350,278,556,500,1000,556,556,333,1000,667,333,1000,350,611,350,350,278,278,500,500,350,556,1000,333,1000,556,333,944,350,500,667,278,333,556,556,556,556,280,556,333,737,370,556,584,333,737,333,400,584,333,333,333,611,556,278,333,333,365,556,834,834,834,611,722,722,722,722,722,722,1000,722,667,667,667,667,278,278,278,278,722,722,778,778,778,778,778,584,778,722,722,722,722,667,667,611,556,556,556,556,556,556,889,556,556,556,556,556,278,278,278,278,611,611,611,611,611,611,611,584,611,611,611,611,611,556,611,556];

/**
 * Invoice / receipt PDF (dependency-free). The same layout is drawn by
 * apps/web/src/lib/invoicePdf.ts (parent web download) and
 * lib/features/parent/services/invoice_pdf_service.dart (phone app); keep the
 * three in step.
 *
 * - Fully paid → "Receipt" with a PAID badge and the payment date.
 *   Otherwise → "Invoice" with Due / Overdue / Partially paid / Cancelled.
 * - Letter size, Helvetica (WinAnsi, so accented Latin names print), long
 *   item lists flow onto more pages and the table header repeats.
 */
const PAGE_WIDTH = 612;
const PAGE_HEIGHT = 792;
const MARGIN = 48;
const FOOTER_SPACE = 44;

const COMPANY_INFO = {
  name: 'Alluwal Education Hub',
  street: '11 McKeever Pl',
  city: 'Brooklyn, NY 11225, United States',
  fullAddress: '11 McKeever Pl, Brooklyn, NY 11225, United States',
  phone: '+1 646-338-1286',
  email: 'billing@alluwaleducationhub.org',
  website: 'alluwaleducationhub.org',
};

const C = {
  brand: '#0369D9',
  ink: '#0F172A',
  body: '#334155',
  muted: '#64748B',
  line: '#E2E8F0',
  soft: '#F8FAFC',
  white: '#FFFFFF',
};

const STATUS_STYLE = {
  paid: {label: 'PAID', fg: '#047857', bg: '#D1FAE5'},
  partial: {label: 'PARTIALLY PAID', fg: '#B45309', bg: '#FEF3C7'},
  overdue: {label: 'OVERDUE', fg: '#B91C1C', bg: '#FEE2E2'},
  due: {label: 'DUE', fg: '#0369D9', bg: '#DBEAFE'},
  cancelled: {label: 'CANCELLED', fg: '#475569', bg: '#E2E8F0'},
};

/** Text a WinAnsi Type1 font can draw: Latin-1 kept, everything else dropped. */
const _toText = (value) =>
  String(value ?? '')
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[–—]/g, '-')
    .replace(/[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]/g, '')
    .replace(/\s+/g, ' ')
    .trim();

const _escapePdfText = (value) =>
  _toText(value).replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');

const _num = (n) => (Number.isInteger(n) ? String(n) : n.toFixed(2));

const _toNumber = (value) => {
  if (value == null) return 0;
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const _toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === 'function') return value.toDate();
  if (typeof value === 'object' && typeof value._seconds === 'number') return new Date(value._seconds * 1000);
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const _longDate = (value) => {
  const date = _toDate(value);
  return date ? date.toLocaleDateString('en-US', {year: 'numeric', month: 'long', day: 'numeric', timeZone: 'America/New_York'}) : '';
};

const _shortDate = (value) => {
  const date = _toDate(value);
  return date ? date.toLocaleDateString('en-US', {year: 'numeric', month: 'short', day: 'numeric', timeZone: 'America/New_York'}) : '';
};

const _longMonth = (date) => date.toLocaleDateString('en-US', {year: 'numeric', month: 'long', timeZone: 'UTC'});

/** "2026-11" → "November 2026"; anything else is returned as written. */
const _periodLabel = (value) => {
  const raw = _toText(value);
  const m = raw.match(/^(\d{4})-(\d{1,2})/);
  if (m) {
    const month = Number(m[2]);
    if (month >= 1 && month <= 12) return _longMonth(new Date(Date.UTC(Number(m[1]), month - 1, 1)));
  }
  return raw;
};

/** Same rules as the parent web page: a start-end range, a "a..b" period, one month, else the issue month. */
const _displayBillingPeriod = (invoice) => {
  const explicit = _toText(invoice.displayBillingPeriod);
  if (explicit) return explicit;
  const start = _periodLabel(invoice.period_start || invoice.periodStart);
  const end = _periodLabel(invoice.period_end || invoice.periodEnd);
  if (start && end) return start === end ? start : `${start} - ${end}`;
  const period = _toText(invoice.billing_period || invoice.billingPeriod || invoice.period);
  if (period.includes('..')) {
    const parts = period.split('..');
    const a = _periodLabel(parts[0]);
    const b = _periodLabel(parts[parts.length - 1]);
    if (a && b) return `${a} - ${b}`;
  }
  if (period) return _periodLabel(period);
  if (start) return start;
  const month = _toText(invoice.billing_month || invoice.billingMonth);
  if (month) return _periodLabel(month);
  const issued = _toDate(invoice.issued_date || invoice.issuedDate);
  return issued ? issued.toLocaleDateString('en-US', {year: 'numeric', month: 'long', timeZone: 'America/New_York'}) : '';
};

const _money = (amount, currency) => {
  try {
    return new Intl.NumberFormat('en-US', {style: 'currency', currency: (currency || 'USD').toString().toUpperCase()}).format(_toNumber(amount));
  } catch (error) {
    return `${currency || 'USD'} ${_toNumber(amount).toFixed(2)}`;
  }
};

/** Width of `text` in points (Helvetica AFM widths, WinAnsi). */
const textWidth = (text, size, bold = false) => {
  const table = bold ? HELVETICA_BOLD : HELVETICA;
  let units = 0;
  for (const ch of _toText(text)) {
    const code = ch.charCodeAt(0);
    units += code >= 32 && code <= 255 ? table[code - 32] || 556 : 556;
  }
  return (units * size) / 1000;
};

/** Split text into lines no wider than `maxWidth` points (long words are cut). */
const wrapToWidth = (value, maxWidth, size, bold = false) => {
  const words = _toText(value).split(' ').filter(Boolean);
  const lines = [];
  let current = '';
  const pushWord = (word) => {
    const next = current ? `${current} ${word}` : word;
    if (textWidth(next, size, bold) <= maxWidth || !current) {
      current = next;
    } else {
      lines.push(current);
      current = word;
    }
  };
  for (const word of words) {
    if (textWidth(word, size, bold) <= maxWidth) {
      pushWord(word);
      continue;
    }
    let chunk = '';
    for (const ch of word) {
      if (textWidth(chunk + ch, size, bold) > maxWidth && chunk) {
        pushWord(chunk);
        chunk = '';
      }
      chunk += ch;
    }
    if (chunk) pushWord(chunk);
  }
  if (current) lines.push(current);
  return lines.length ? lines : [''];
};

class PdfCanvas {
  constructor() {
    this.ops = [];
  }

  rgb(hex) {
    const h = hex.replace('#', '');
    return [0, 2, 4].map((i) => (parseInt(h.slice(i, i + 2), 16) / 255).toFixed(3)).join(' ');
  }

  fillRect(x, y, w, h, color) {
    this.ops.push(`${this.rgb(color)} rg ${_num(x)} ${_num(y)} ${_num(w)} ${_num(h)} re f`);
  }

  /** Filled rounded rectangle; (x, y) is the bottom-left corner. */
  roundRect(x, y, w, h, r, color) {
    const k = 0.5523 * r;
    const p = (a, b) => `${_num(a)} ${_num(b)}`;
    this.ops.push(
      `${this.rgb(color)} rg ${p(x + r, y)} m ${p(x + w - r, y)} l ` +
        `${p(x + w - r + k, y)} ${p(x + w, y + r - k)} ${p(x + w, y + r)} c ${p(x + w, y + h - r)} l ` +
        `${p(x + w, y + h - r + k)} ${p(x + w - r + k, y + h)} ${p(x + w - r, y + h)} c ${p(x + r, y + h)} l ` +
        `${p(x + r - k, y + h)} ${p(x, y + h - r + k)} ${p(x, y + h - r)} c ${p(x, y + r)} l ` +
        `${p(x, y + r - k)} ${p(x + r - k, y)} ${p(x + r, y)} c f`
    );
  }

  line(x1, y1, x2, y2, color, width = 0.75) {
    this.ops.push(`${width} w ${this.rgb(color)} RG ${_num(x1)} ${_num(y1)} m ${_num(x2)} ${_num(y2)} l S`);
  }

  text(x, y, value, {size = 10, color = C.ink, bold = false, align = 'left'} = {}) {
    const w = align === 'left' ? 0 : textWidth(value, size, bold);
    const left = align === 'right' ? x - w : align === 'center' ? x - w / 2 : x;
    this.ops.push(`${this.rgb(color)} rg BT /${bold ? 'F2' : 'F1'} ${size} Tf ${_num(left)} ${_num(y)} Td (${_escapePdfText(value)}) Tj ET`);
  }
}

/** Everything the layout needs, in one place, from a raw or parsed invoice. */
const describeInvoice = (invoice, now = new Date()) => {
  const currency = _toText(invoice.currency || 'USD') || 'USD';
  const total = _toNumber(invoice.total_amount ?? invoice.totalAmount);
  const paid = _toNumber(invoice.paid_amount ?? invoice.paidAmount);
  const remaining = Math.max(0, Number((total - paid).toFixed(2)));
  const rawStatus = _toText(invoice.status).toLowerCase();
  const dueDate = _toDate(invoice.dueDate || invoice.due_date);
  let status;
  if (rawStatus === 'cancelled' || rawStatus === 'canceled' || rawStatus === 'void') status = 'cancelled';
  else if (rawStatus === 'paid' || (total > 0 && remaining <= 0)) status = 'paid';
  else if (dueDate && dueDate.getTime() < now.getTime()) status = 'overdue';
  else if (paid > 0) status = 'partial';
  else status = 'due';
  const items = (Array.isArray(invoice.items) ? invoice.items : []).map((item, index) => ({
    description: _toText(item.description) || `Item ${index + 1}`,
    quantity: _toNumber(item.quantity) || 1,
    unitPrice: _toNumber(item.unit_price ?? item.unitPrice),
    total: _toNumber(item.total),
  }));
  return {
    number: _toText(invoice.invoiceNumber || invoice.invoice_number || invoice.id),
    currency,
    total,
    paid,
    remaining,
    status,
    isReceipt: status === 'paid',
    issuedDate: _toDate(invoice.issuedDate || invoice.issued_date || invoice.createdAt || invoice.created_at) || now,
    dueDate,
    paidDate: _toDate(invoice.lastPaymentAt || invoice.last_payment_at || invoice.paidAt || invoice.paid_at),
    accessCutoffDate: _toDate(invoice.accessCutoffDate || invoice.access_cutoff_date),
    billingPeriod: _displayBillingPeriod(invoice),
    parentName: _toText(invoice.parentName),
    studentName: _toText(invoice.studentName),
    items,
  };
};

const INNER = PAGE_WIDTH - MARGIN * 2;
// Item table columns: description, qty, unit price, amount (right edges for numbers).
const COL_QTY_RIGHT = MARGIN + INNER * 0.64;
const COL_PRICE_RIGHT = MARGIN + INNER * 0.82;
const COL_AMOUNT_RIGHT = MARGIN + INNER;
const DESC_WIDTH = INNER * 0.56 - 8;

const _drawHeader = (c, y, d) => {
  c.roundRect(MARGIN, y - 40, 40, 40, 9, C.brand);
  c.text(MARGIN + 20, y - 25, 'AEH', {size: 12, bold: true, color: C.white, align: 'center'});
  c.text(MARGIN + 52, y - 17, COMPANY_INFO.name, {size: 14, bold: true});
  c.text(MARGIN + 52, y - 32, COMPANY_INFO.website, {size: 9, color: C.muted});
  c.text(PAGE_WIDTH - MARGIN, y - 20, d.isReceipt ? 'Receipt' : 'Invoice', {size: 24, bold: true, align: 'right'});
  if (d.number) c.text(PAGE_WIDTH - MARGIN, y - 36, d.number, {size: 10, color: C.muted, align: 'right'});
  c.line(MARGIN, y - 58, PAGE_WIDTH - MARGIN, y - 58, C.line);
  return 58;
};

const _drawHero = (c, y, d) => {
  const h = 76;
  c.roundRect(MARGIN, y - h, INNER, h, 12, C.soft);
  let label;
  let amount;
  let sub;
  if (d.status === 'paid') {
    label = 'AMOUNT PAID';
    amount = d.paid || d.total;
    sub = d.paidDate ? `Paid on ${_longDate(d.paidDate)}` : 'Paid in full';
  } else if (d.status === 'cancelled') {
    label = 'INVOICE TOTAL';
    amount = d.total;
    sub = 'This invoice was cancelled. Nothing is owed.';
  } else {
    label = d.paid > 0 ? 'BALANCE DUE' : 'AMOUNT DUE';
    amount = d.remaining;
    sub = d.dueDate ? `${d.status === 'overdue' ? 'Was due' : 'Due'} ${_longDate(d.dueDate)}` : '';
  }
  c.text(MARGIN + 20, y - 24, label, {size: 8.5, bold: true, color: C.muted});
  c.text(MARGIN + 20, y - 50, _money(amount, d.currency), {size: 24, bold: true});
  if (sub) c.text(MARGIN + 20, y - 66, sub, {size: 9.5, color: C.body});
  const style = STATUS_STYLE[d.status];
  const pillW = textWidth(style.label, 8.5, true) + 22;
  c.roundRect(PAGE_WIDTH - MARGIN - 20 - pillW, y - 48, pillW, 22, 11, style.bg);
  c.text(PAGE_WIDTH - MARGIN - 20 - pillW / 2, y - 40, style.label, {size: 8.5, bold: true, color: style.fg, align: 'center'});
  return h;
};

const _metaColumns = (d) => {
  const billed = [];
  if (d.parentName) billed.push({text: d.parentName, bold: true});
  if (d.studentName) billed.push({text: `Student: ${d.studentName}`});
  if (!billed.length) billed.push({text: 'Parent', bold: true});
  const details = [[d.isReceipt ? 'Receipt for' : 'Invoice', d.number]];
  details.push(['Issued', _shortDate(d.issuedDate)]);
  if (d.dueDate && d.status !== 'paid' && d.status !== 'cancelled') details.push(['Due', _shortDate(d.dueDate)]);
  if (d.paidDate && d.status === 'paid') details.push(['Paid', _shortDate(d.paidDate)]);
  if (d.billingPeriod) details.push(['Period', d.billingPeriod]);
  if (d.accessCutoffDate && d.status !== 'paid' && d.status !== 'cancelled') details.push(['Access until', _shortDate(d.accessCutoffDate)]);
  const from = [
    {text: COMPANY_INFO.name, bold: true},
    {text: COMPANY_INFO.street},
    {text: COMPANY_INFO.city},
    {text: COMPANY_INFO.phone},
    {text: COMPANY_INFO.email},
  ];
  return {billed, details: details.filter(([, v]) => v), from};
};

const _drawMeta = (c, y, d) => {
  const {billed, details, from} = _metaColumns(d);
  const colW = INNER / 3;
  const top = y - 4;
  const heading = (x, label) => c.text(x, top, label, {size: 8, bold: true, color: C.muted});
  const lineH = 14;
  let x = MARGIN;
  heading(x, 'BILLED TO');
  let rows = 0;
  billed.forEach((entry) => {
    for (const ln of wrapToWidth(entry.text, colW - 14, 10, entry.bold)) {
      c.text(x, top - 18 - rows * lineH, ln, {size: 10, bold: entry.bold, color: entry.bold ? C.ink : C.body});
      rows += 1;
    }
  });
  let maxRows = rows;
  x = MARGIN + colW;
  heading(x, 'DETAILS');
  details.forEach(([label, value], i) => {
    c.text(x, top - 18 - i * lineH, label, {size: 9.5, color: C.muted});
    c.text(x + 68, top - 18 - i * lineH, value, {size: 9.5, color: C.ink});
  });
  maxRows = Math.max(maxRows, details.length);
  x = MARGIN + colW * 2;
  heading(x, 'FROM');
  from.forEach((entry, i) => {
    c.text(x, top - 18 - i * lineH, entry.text, {size: 9.5, bold: entry.bold, color: entry.bold ? C.ink : C.body});
  });
  maxRows = Math.max(maxRows, from.length);
  return 18 + maxRows * lineH;
};

const _metaHeight = (d) => {
  const {billed, details, from} = _metaColumns(d);
  const billedRows = billed.reduce((n, e) => n + wrapToWidth(e.text, INNER / 3 - 14, 10, e.bold).length, 0);
  return 18 + Math.max(billedRows, details.length, from.length) * 14;
};

const TABLE_HEAD = 26;

const _drawTableHead = (c, y) => {
  c.text(MARGIN, y - 14, 'DESCRIPTION', {size: 8, bold: true, color: C.muted});
  c.text(COL_QTY_RIGHT, y - 14, 'QTY', {size: 8, bold: true, color: C.muted, align: 'right'});
  c.text(COL_PRICE_RIGHT, y - 14, 'UNIT PRICE', {size: 8, bold: true, color: C.muted, align: 'right'});
  c.text(COL_AMOUNT_RIGHT, y - 14, 'AMOUNT', {size: 8, bold: true, color: C.muted, align: 'right'});
  c.line(MARGIN, y - TABLE_HEAD + 4, PAGE_WIDTH - MARGIN, y - TABLE_HEAD + 4, C.ink, 0.9);
  return TABLE_HEAD;
};

const _itemLines = (item) => wrapToWidth(item.description, DESC_WIDTH, 10);
const _itemHeight = (item) => 12 + _itemLines(item).length * 13;

const _drawItem = (c, y, item, currency) => {
  const lines = _itemLines(item);
  const h = 12 + lines.length * 13;
  lines.forEach((ln, i) => c.text(MARGIN, y - 15 - i * 13, ln, {size: 10}));
  const qty = Number.isInteger(item.quantity) ? String(item.quantity) : item.quantity.toFixed(2);
  c.text(COL_QTY_RIGHT, y - 15, qty, {size: 10, color: C.body, align: 'right'});
  c.text(COL_PRICE_RIGHT, y - 15, _money(item.unitPrice, currency), {size: 10, color: C.body, align: 'right'});
  c.text(COL_AMOUNT_RIGHT, y - 15, _money(item.total, currency), {size: 10, align: 'right'});
  c.line(MARGIN, y - h, PAGE_WIDTH - MARGIN, y - h, C.line);
  return h;
};

const _drawNoItems = (c, y) => {
  c.text(MARGIN, y - 15, 'No items on this invoice', {size: 10, color: C.muted});
  c.line(MARGIN, y - 24, PAGE_WIDTH - MARGIN, y - 24, C.line);
  return 24;
};

const _totalsRows = (d) => {
  const rows = [['Total', _money(d.total, d.currency), false]];
  if (d.status === 'cancelled') return rows;
  rows.push(['Amount paid', d.paid > 0 ? `-${_money(d.paid, d.currency)}` : _money(0, d.currency), false]);
  rows.push([d.isReceipt ? 'Balance' : 'Balance due', _money(d.remaining, d.currency), true]);
  return rows;
};

const _drawTotals = (c, y, d) => {
  const rows = _totalsRows(d);
  const left = MARGIN + INNER * 0.5;
  let rowY = y - 18;
  rows.forEach(([label, value, strong]) => {
    if (strong) {
      c.line(left, rowY + 12, PAGE_WIDTH - MARGIN, rowY + 12, C.line);
      rowY -= 6;
    }
    c.text(left, rowY, label, {size: strong ? 11 : 10, bold: strong, color: strong ? C.ink : C.body});
    c.text(PAGE_WIDTH - MARGIN, rowY, value, {size: strong ? 13 : 10, bold: strong, color: strong ? C.brand : C.ink, align: 'right'});
    rowY -= 20;
  });
  return y - rowY - 6;
};

const _totalsHeight = (d) => {
  const rows = _totalsRows(d);
  return 18 + rows.length * 20 + (rows.some((r) => r[2]) ? 6 : 0) - 6;
};

const _noteText = (d) => {
  if (d.status === 'paid') return 'Thank you for your payment. Keep this receipt for your records.';
  if (d.status === 'cancelled') return `Questions about this invoice? Write to ${COMPANY_INFO.email}.`;
  return 'Pay online from your parent account at alluwaleducationhub.org, or with the Pay link in your invoice email.';
};

const _drawNote = (c, y, d) => {
  const lines = wrapToWidth(_noteText(d), INNER - 32, 9.5);
  const h = 20 + lines.length * 13;
  c.roundRect(MARGIN, y - h, INNER, h, 10, C.soft);
  lines.forEach((ln, i) => c.text(MARGIN + 16, y - 17 - i * 13, ln, {size: 9.5, color: C.body}));
  return h;
};

const _noteHeight = (d) => 20 + wrapToWidth(_noteText(d), INNER - 32, 9.5).length * 13;

const _drawPageFooter = (c, page, pages) => {
  const y = MARGIN - 6;
  c.line(MARGIN, y + 14, PAGE_WIDTH - MARGIN, y + 14, C.line);
  c.text(MARGIN, y, `${COMPANY_INFO.name}  ·  ${COMPANY_INFO.email}  ·  ${COMPANY_INFO.phone}`.replace(/·/g, '\xB7'), {size: 8, color: C.muted});
  c.text(PAGE_WIDTH - MARGIN, y, `Page ${page} of ${pages}`, {size: 8, color: C.muted, align: 'right'});
};

/**
 * Each page's drawing operators. Blocks flow top to bottom; one that would
 * cross the footer starts a new page, and item rows re-draw the table header.
 */
const buildInvoicePdfPages = (invoice, {now = new Date()} = {}) => {
  const d = describeInvoice(invoice, now);
  const blocks = [
    {height: 58, gap: 22, draw: (c, y) => _drawHeader(c, y, d)},
    {height: 76, gap: 26, draw: (c, y) => _drawHero(c, y, d)},
    {height: _metaHeight(d), gap: 26, draw: (c, y) => _drawMeta(c, y, d)},
    {height: TABLE_HEAD, gap: 0, draw: (c, y) => _drawTableHead(c, y), keepWithNext: true},
  ];
  if (d.items.length === 0) {
    blocks.push({height: 24, gap: 0, draw: (c, y) => _drawNoItems(c, y)});
  } else {
    d.items.forEach((item, i) => {
      // The last row stays with the totals so they never sit alone on a page.
      const last = i === d.items.length - 1;
      blocks.push({height: _itemHeight(item), gap: 0, draw: (c, y) => _drawItem(c, y, item, d.currency), tableRow: true, keepWithNext: last});
    });
  }
  blocks.push({height: _totalsHeight(d), gap: 22, draw: (c, y) => _drawTotals(c, y, d)});
  blocks.push({height: _noteHeight(d), gap: 0, draw: (c, y) => _drawNote(c, y, d)});

  const bottom = MARGIN + FOOTER_SPACE;
  const pages = [new PdfCanvas()];
  let y = PAGE_HEIGHT - MARGIN;
  blocks.forEach((block, index) => {
    const next = blocks[index + 1];
    const need = block.height + (block.keepWithNext && next ? next.height : 0);
    if (y - need < bottom && y < PAGE_HEIGHT - MARGIN) {
      pages.push(new PdfCanvas());
      y = PAGE_HEIGHT - MARGIN;
      if (block.tableRow) y -= _drawTableHead(pages[pages.length - 1], y);
    }
    block.draw(pages[pages.length - 1], y);
    y -= block.height + block.gap;
  });
  pages.forEach((page, i) => _drawPageFooter(page, i + 1, pages.length));
  return pages.map((page) => page.ops.join('\n'));
};

const _buildPdf = (pages) => {
  const font = (name) => `<< /Type /Font /Subtype /Type1 /BaseFont /${name} /Encoding /WinAnsiEncoding >>`;
  const pageIds = pages.map((_, i) => 5 + i * 2);
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    `<< /Type /Pages /Kids [${pageIds.map((id) => `${id} 0 R`).join(' ')}] /Count ${pages.length} >>`,
    font('Helvetica'),
    font('Helvetica-Bold'),
  ];
  pages.forEach((content, i) => {
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${PAGE_WIDTH} ${PAGE_HEIGHT}] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents ${pageIds[i] + 1} 0 R >>`);
    objects.push(`<< /Length ${Buffer.byteLength(content, 'latin1')} >>\nstream\n${content}\nendstream`);
  });
  let pdf = '%PDF-1.4\n';
  const offsets = [];
  objects.forEach((object, index) => {
    offsets.push(Buffer.byteLength(pdf, 'latin1'));
    pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = Buffer.byteLength(pdf, 'latin1');
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  offsets.forEach((offset) => {
    pdf += `${String(offset).padStart(10, '0')} 00000 n \n`;
  });
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf, 'latin1');
};

const generateInvoicePdfBuffer = (invoice, options) => _buildPdf(buildInvoicePdfPages(invoice, options));

module.exports = {
  generateInvoicePdfBuffer,
  buildInvoicePdfPages,
  describeInvoice,
  textWidth,
  wrapToWidth,
  COMPANY_INFO,
};
