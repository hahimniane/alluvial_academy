#!/usr/bin/env node
/**
 * Finance import from the 2026 spreadsheet (staff payments, fees, budget).
 *
 * DRY RUN BY DEFAULT. It reads the workbook, reads production (read-only) to
 * match people and to compare September invoices, and writes a review:
 *   ~/alluwal-scratch/sheet-import-2026-review.json
 *   ~/alluwal-scratch/sheet-import-2026-review.md
 *
 * Usage (from functions/):
 *   node scripts/finance_import_2026_sheet.js                 # dry run
 *   node scripts/finance_import_2026_sheet.js --no-firestore  # workbook only
 *   node scripts/finance_import_2026_sheet.js --apply --yes   # writes docs
 *   node scripts/finance_import_2026_sheet.js --remove-batch --yes
 *
 * --apply writes only proposals that matched a user with high confidence, and
 * tags every doc import_batch:'sheet-2026' so --remove-batch can delete them.
 * Existing docs are never overwritten (batch.create fails on a clash).
 *
 * Options: --file <xlsx>  --out-dir <dir>  --credentials <service-account.json>
 *
 * The workbook is a zip of XML. It is read with the system `unzip -p`, so no
 * xlsx library is needed.
 */

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const IMPORT_BATCH = 'sheet-2026';
const SOURCE = 'sheet_import_2026';
const PROJECT_ID = 'alluwal-academy';
const HOME = os.homedir();
const DEFAULT_FILE = path.join(HOME, 'alluwal-scratch', 'finsheet', '2026_Finance.xlsx');
const DEFAULT_OUT = path.join(HOME, 'alluwal-scratch');
const DEFAULT_CREDENTIALS = path.join(
  HOME,
  'Downloads',
  'alluwal-academy-firebase-adminsdk-fbsvc-79870a81d3.json'
);

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthKey = (i) => `2026-${String(i + 1).padStart(2, '0')}`;
const IMPORT_MONTHS = 9; // Jan-Sep

/* ------------------------------------------------------------------ */
/* Workbook reading (zip of XML via `unzip -p`)                        */
/* ------------------------------------------------------------------ */

function unzipText(file, inner) {
  return execFileSync('unzip', ['-p', file, inner], { maxBuffer: 512 * 1024 * 1024 }).toString('utf8');
}

function decodeXml(s) {
  return s
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&amp;/g, '&');
}

function readSharedStrings(file) {
  const xml = unzipText(file, 'xl/sharedStrings.xml');
  const out = [];
  const re = /<si>([\s\S]*?)<\/si>/g;
  let m;
  while ((m = re.exec(xml))) {
    out.push([...m[1].matchAll(/<t[^>]*>([\s\S]*?)<\/t>/g)].map((a) => decodeXml(a[1])).join(''));
  }
  return out;
}

/** Sheet names in workbook order, each mapped to its worksheet file number. */
function readSheetIndex(file) {
  const wb = unzipText(file, 'xl/workbook.xml');
  const rels = unzipText(file, 'xl/_rels/workbook.xml.rels');
  const target = {};
  for (const m of rels.matchAll(/<Relationship\b[^>]*>/g)) {
    const id = (m[0].match(/\bId="([^"]+)"/) || [])[1];
    const t = (m[0].match(/\bTarget="([^"]+)"/) || [])[1];
    if (id && t) target[id] = t;
  }
  const sheets = [];
  for (const m of wb.matchAll(/<sheet\b[^>]*>/g)) {
    const name = decodeXml((m[0].match(/\bname="([^"]*)"/) || [])[1] || '');
    const rid = (m[0].match(/\br:id="([^"]+)"/) || [])[1];
    const t = target[rid] || '';
    const n = (t.match(/sheet(\d+)\.xml$/) || [])[1];
    if (n) sheets.push({ name, number: Number(n) });
  }
  return sheets;
}

/** Returns { [rowNumber]: { [columnLetters]: value } }; empty cells are omitted. */
function readSheet(file, number, sharedStrings) {
  const xml = unzipText(file, `xl/worksheets/sheet${number}.xml`);
  const rows = {};
  const re = /<c r="([A-Z]+)(\d+)"([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g;
  let m;
  while ((m = re.exec(xml))) {
    const [, col, row, attrs, inner] = m;
    if (inner === undefined) continue;
    const type = (attrs.match(/\bt="(\w+)"/) || [])[1];
    const v = (inner.match(/<v>([\s\S]*?)<\/v>/) || [])[1];
    let val;
    if (type === 's') val = sharedStrings[Number(v)];
    else if (type === 'str') val = v !== undefined ? decodeXml(v) : undefined;
    else if (type === 'inlineStr') {
      val = [...inner.matchAll(/<t[^>]*>([\s\S]*?)<\/t>/g)].map((a) => decodeXml(a[1])).join('');
    } else if (type === 'b') val = v === '1';
    else if (type === 'e') val = `#ERR:${v}`;
    else if (v !== undefined) val = Number(v);
    if (val === undefined || val === '') continue;
    (rows[row] = rows[row] || {})[col] = val;
  }
  return rows;
}

/* ------------------------------------------------------------------ */
/* Cell helpers                                                        */
/* ------------------------------------------------------------------ */

const isBlankText = (v) => typeof v === 'string' && v.trim() === '';
const isPlaceholder = (v) => typeof v === 'string' && /^[\s\-_–—]+$/.test(v);

/**
 * Money cell -> { value, issue }.
 * Numbers pass through. Text that holds a number ("169,64", "$40") is parsed
 * and reported as an issue. Text that does not hold a number is an issue with
 * value null. Blank cells and dash placeholders return value null, no issue.
 */
function parseMoney(v) {
  if (v === undefined || v === null) return { value: null, issue: null };
  if (typeof v === 'number') return { value: v, issue: null };
  if (typeof v !== 'string' || isBlankText(v) || isPlaceholder(v)) return { value: null, issue: null };
  const cleaned = v.replace(/[$\s]/g, '');
  if (/^-?\d{1,3}(,\d{3})+(\.\d+)?$/.test(cleaned)) {
    return { value: Number(cleaned.replace(/,/g, '')), issue: `text "${v}" read as ${cleaned.replace(/,/g, '')}` };
  }
  if (/^-?\d+,\d{1,2}$/.test(cleaned)) {
    const n = Number(cleaned.replace(',', '.'));
    return { value: n, issue: `text "${v}" read as ${n} (comma as decimal)` };
  }
  if (/^-?\d+(\.\d+)?$/.test(cleaned)) {
    return { value: Number(cleaned), issue: `text "${v}" stored as text` };
  }
  return { value: null, issue: `text "${v}" in a money cell` };
}

function parseHours(...cells) {
  let total = 0;
  let any = false;
  for (const v of cells) {
    if (v === undefined || v === null) continue;
    if (typeof v === 'number') {
      total += v;
      any = true;
    } else if (typeof v === 'string') {
      const m = v.match(/-?\d+(?:[.,]\d+)?/);
      if (m) {
        total += Number(m[0].replace(',', '.'));
        any = true;
      }
    }
  }
  return any ? Math.round(total * 100) / 100 : null;
}

function excelDateToIso(v) {
  if (typeof v === 'number' && v > 20000 && v < 80000) {
    return new Date(Date.UTC(1899, 11, 30) + Math.round(v * 86400000)).toISOString().slice(0, 10);
  }
  if (typeof v === 'string') {
    const m = v.trim().match(/^(\d{1,2})\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{4})$/);
    if (m) return `${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`;
    if (/^\d{4}-\d{2}-\d{2}$/.test(v.trim())) return v.trim();
  }
  return null;
}

const round2 = (n) => Math.round(n * 100) / 100;

function median(nums) {
  const a = nums.filter((n) => typeof n === 'number' && isFinite(n)).sort((x, y) => x - y);
  if (!a.length) return 0;
  const mid = Math.floor(a.length / 2);
  return a.length % 2 ? a[mid] : (a[mid - 1] + a[mid]) / 2;
}

/* ------------------------------------------------------------------ */
/* Names                                                               */
/* ------------------------------------------------------------------ */

const HONORIFICS = new Set(['sheikh', 'sheik', 'shaykh', 'shaikh', 'dr', 'mr', 'mrs', 'ms', 'ustaz', 'ustadh']);

function normalizeName(s) {
  if (!s) return '';
  return String(s)
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/ı/g, 'i')
    .replace(/İ/g, 'i')
    .toLowerCase()
    .replace(/[^a-z\s]/g, ' ')
    .split(/\s+/)
    .filter((t) => t && !HONORIFICS.has(t))
    .join(' ');
}

function levenshtein(a, b) {
  if (a === b) return 0;
  const m = a.length;
  const n = b.length;
  if (!m) return n;
  if (!n) return m;
  let prev = Array.from({ length: n + 1 }, (_, j) => j);
  for (let i = 1; i <= m; i++) {
    const cur = [i];
    for (let j = 1; j <= n; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[n];
}

function tokenSimilarity(a, b) {
  if (a === b) return 1;
  if (a.length === 1 || b.length === 1) return a[0] === b[0] ? 0.6 : 0;
  return 1 - levenshtein(a, b) / Math.max(a.length, b.length);
}

/**
 * How well two names agree, 0..1. Each token of the shorter name is paired
 * with its best token in the longer name; extra tokens on the longer side cost
 * a little so "Ali Bah" prefers "Ali Bah" over "Ali Bah Diallo".
 */
function nameSimilarity(a, b) {
  const ta = normalizeName(a).split(' ').filter(Boolean);
  const tb = normalizeName(b).split(' ').filter(Boolean);
  if (!ta.length || !tb.length) return 0;
  const [short, long] = ta.length <= tb.length ? [ta, tb] : [tb, ta];
  const used = new Set();
  let total = 0;
  for (const t of short) {
    let best = 0;
    let bestIdx = -1;
    long.forEach((u, idx) => {
      if (used.has(idx)) return;
      const s = tokenSimilarity(t, u);
      if (s > best) {
        best = s;
        bestIdx = idx;
      }
    });
    if (bestIdx >= 0) used.add(bestIdx);
    total += best;
  }
  const base = total / short.length;
  const extra = long.length - short.length;
  return base - Math.min(0.12, extra * 0.04);
}

/**
 * Best user for a sheet name. confidence:
 *   matched   - two or more name tokens and either an exact name or a strong score with a clear winner
 *   possible  - plausible but ambiguous, a single name, or a weaker score
 *   unmatched - nothing close
 */
function matchPerson(sheetName, users) {
  const scored = users
    .map((u) => ({ user: u, score: nameSimilarity(sheetName, u.name) + (u.active ? 0.001 : 0) }))
    .filter((s) => s.score > 0.5)
    .sort((x, y) => y.score - x.score);
  if (!scored.length) return { confidence: 'unmatched', candidates: [] };
  const top = scored[0];
  const second = scored[1];
  const gap = second ? top.score - second.score : 1;
  const sheetTokens = normalizeName(sheetName).split(' ').filter(Boolean).length;
  const candidates = scored.slice(0, 3).map((s) => ({ uid: s.user.uid, name: s.user.name, score: round2(s.score) }));
  let confidence = 'possible';
  const exact = top.score >= 0.99 && (!second || second.score < 0.99);
  if (sheetTokens >= 2 && (exact || (top.score >= 0.85 && gap >= 0.1))) confidence = 'matched';
  else if (top.score < 0.7) confidence = 'unmatched';
  return { confidence, user: top.user, score: round2(top.score), candidates };
}

const stripPhone = (s) =>
  String(s || '')
    .replace(/to contact:?/gi, '')
    .replace(/\+?\d[\d\s().-]{6,}\d/g, '')
    .replace(/\s+/g, ' ')
    .replace(/[:\s]+$/, '')
    .trim();

/* ------------------------------------------------------------------ */
/* Sheet parsing                                                       */
/* ------------------------------------------------------------------ */

// Staff tab column groups per month. Layout changes from month to month.
const STAFF_COLS = [
  { amount: 'D', deducted: 'E', date: 'F', hours: ['G'] },
  { amount: 'H', deducted: 'I', date: 'J', hours: ['K'] },
  { amount: 'L', deducted: 'M', fee: 'N', hours: ['O', 'P'] },
  { amount: 'Q', deducted: 'R', fee: 'S', hours: ['T', 'U'] },
  { amount: 'V', deducted: 'W', date: 'X', hours: ['Y'] },
  { amount: 'Z', deducted: 'AA', date: 'AB', hours: ['AC', 'AD'] },
  { amount: 'AE', deducted: 'AF', date: 'AG', hours: ['AH', 'AI'] },
  { amount: 'AJ', deducted: 'AK', date: 'AL', hours: ['AM', 'AN'] },
  { amount: 'AO', status: 'AP', deducted: 'AQ', rate: 'AR', date: 'AS', hours: ['AT', 'AU'] },
];

const STAFF_FIRST_ROW = 4;
const STAFF_LAST_ROW = 30;
const STAFF_TOTAL_ROW = 31;
const ADMIN_FIRST_ROW = 33;
const ADMIN_LAST_ROW = 42;
const COST_FIRST_ROW = 43;
const COST_LAST_ROW = 47;
const ADMIN_TOTAL_ROW = 48;

const COST_ROWS = {
  'transfer fees': { category: 'transfer_fees', label: 'Transfer fees' },
  internet: { category: 'software', label: 'Internet' },
  bank: { category: 'other', label: 'Bank' },
  other: { category: 'other', label: 'Other' },
  'coding subcriptions': { category: 'software', label: 'Coding subscriptions' },
  'coding subscriptions': { category: 'software', label: 'Coding subscriptions' },
};

function cell(rows, col, row) {
  return rows[row] ? rows[row][col] : undefined;
}

function parseStaffTab(rows, flags) {
  const teachers = [];
  for (let r = STAFF_FIRST_ROW; r <= STAFF_LAST_ROW; r++) {
    const name = String(cell(rows, 'A', r) || '').trim();
    if (!name) continue;
    const person = {
      row: r,
      sheetName: name,
      code: String(cell(rows, 'B', r) || '').trim() || null,
      sentTo: stripPhone(cell(rows, 'C', r)) || null,
      months: [],
    };
    STAFF_COLS.forEach((cols, i) => {
      const amount = parseMoney(cell(rows, cols.amount, r));
      const deducted = parseMoney(cell(rows, cols.deducted, r));
      const feeRaw = cols.fee ? cell(rows, cols.fee, r) : undefined;
      const fee = parseMoney(feeRaw);
      const status = cols.status ? String(cell(rows, cols.status, r) || '').trim() || null : null;
      const dateRaw = cols.date ? cell(rows, cols.date, r) : undefined;
      const hours = parseHours(...cols.hours.map((c) => cell(rows, c, r)));
      const entry = {
        month: monthKey(i),
        amount: amount.value,
        deducted: deducted.value,
        transferFee: fee.value,
        status,
        datePaid: dateRaw === undefined ? null : excelDateToIso(dateRaw),
        hours,
        cells: { amount: `${cols.amount}${r}` },
      };
      for (const [what, parsed, col] of [
        ['amount', amount, cols.amount],
        ['deducted', deducted, cols.deducted],
        ['transfer fee', fee, cols.fee],
      ]) {
        if (parsed.issue) {
          flags.push({
            severity: 'warn',
            kind: 'non_numeric_money',
            tab: 'Staff',
            cell: `${col}${r}`,
            month: monthKey(i),
            message: `${name}: ${what} ${parsed.issue}`,
          });
        }
      }
      if (typeof amount.value === 'number' && amount.value < 0) {
        flags.push({
          severity: 'warn', kind: 'negative', tab: 'Staff', cell: `${cols.amount}${r}`, month: monthKey(i),
          message: `${name}: negative amount ${amount.value}`,
        });
      }
      person.months.push(entry);
    });
    teachers.push(person);
  }

  // Hours cells that are not numbers ("15hrs", "3 hrs") are readable but worth a look.
  const admins = [];
  for (let r = ADMIN_FIRST_ROW; r <= ADMIN_LAST_ROW; r++) {
    const name = String(cell(rows, 'A', r) || '').trim();
    if (!name) continue;
    const monthly = [];
    [0, 1, 2, 3].forEach((i) => {
      const col = STAFF_COLS[i].amount;
      const parsed = parseMoney(cell(rows, col, r));
      if (parsed.issue) {
        flags.push({
          severity: 'warn', kind: 'non_numeric_money', tab: 'Staff', cell: `${col}${r}`, month: monthKey(i),
          message: `${name}: ${parsed.issue}`,
        });
      }
      monthly.push({ month: monthKey(i), amount: parsed.value, cell: `${col}${r}` });
    });
    admins.push({
      row: r,
      sheetName: name,
      pct: typeof cell(rows, 'B', r) === 'number' ? cell(rows, 'B', r) : null,
      salary: typeof cell(rows, 'C', r) === 'number' ? cell(rows, 'C', r) : null,
      months: monthly,
    });
  }

  const costs = [];
  for (let r = COST_FIRST_ROW; r <= COST_LAST_ROW; r++) {
    const label = String(cell(rows, 'A', r) || '').trim();
    const def = COST_ROWS[label.toLowerCase()];
    if (!label) continue;
    if (!def) {
      flags.push({
        severity: 'info', kind: 'unknown_cost_row', tab: 'Staff', cell: `A${r}`, month: null,
        message: `Cost row "${label}" is not mapped; skipped`,
      });
      continue;
    }
    const monthly = [];
    [0, 1, 2, 3].forEach((i) => {
      const col = STAFF_COLS[i].amount;
      const parsed = parseMoney(cell(rows, col, r));
      if (parsed.issue) {
        flags.push({
          severity: 'warn', kind: 'non_numeric_money', tab: 'Staff', cell: `${col}${r}`, month: monthKey(i),
          message: `${label}: ${parsed.issue}`,
        });
      }
      monthly.push({ month: monthKey(i), amount: parsed.value, cell: `${col}${r}` });
    });
    costs.push({ row: r, label: def.label, category: def.category, months: monthly });
  }

  const stated = (row) => STAFF_COLS.map((c) => {
    const v = cell(rows, c.amount, row);
    return typeof v === 'number' ? v : null;
  });

  return {
    teachers,
    admins,
    costs,
    statedTeacherTotals: stated(STAFF_TOTAL_ROW),
    statedAdminTotals: stated(ADMIN_TOTAL_ROW),
    septAddendum: parseSeptAddendum(rows),
  };
}

/** Rows 101+ list "Sept" amounts by first name; used only as a cross-check. */
function parseSeptAddendum(rows) {
  const out = [];
  for (let r = 100; r <= 130; r++) {
    const name = cell(rows, 'F', r);
    const amount = cell(rows, 'H', r);
    if (typeof name === 'string' && typeof amount === 'number' && /sept/i.test(String(cell(rows, 'G', r) || ''))) {
      out.push({ row: r, name: name.trim(), amount });
    }
  }
  return out;
}

function parseBudgetTab(rows) {
  const out = [];
  for (let r = 4; r <= 15; r++) {
    const label = String(cell(rows, 'G', r) || '').trim();
    const i = MONTHS.findIndex((m) => m === label);
    if (i < 0) continue;
    const num = (c) => {
      const v = cell(rows, c, r);
      return typeof v === 'number' ? v : null;
    };
    const textCells = ['H', 'I', 'J', 'K', 'L', 'M'].filter((c) => typeof cell(rows, c, r) === 'string');
    out.push({
      month: monthKey(i),
      row: r,
      income: num('H'),
      staff: num('I'),
      admin: num('J'),
      other: num('K'),
      totalCost: num('L'),
      profit: num('M'),
      nature: cell(rows, 'N', r) || null,
      textCells,
    });
  }
  return out;
}

const FEES_COLS = MONTHS.map((_, i) => {
  const base = 14 + i * 3; // N = 14
  const letter = (n) => {
    let s = '';
    while (n > 0) {
      s = String.fromCharCode(65 + ((n - 1) % 26)) + s;
      n = Math.floor((n - 1) / 26);
    }
    return s;
  };
  return { paid: letter(base), owed: letter(base + 1), date: letter(base + 2) };
});

function parseFeesTab(rows, flags) {
  const students = [];
  let totalRow = null;
  let totalRowNumber = null;
  const maxRow = Math.max(...Object.keys(rows).map(Number));
  for (let r = 5; r <= maxRow; r++) {
    if (String(cell(rows, 'B', r) || '').trim().toLowerCase() === 'total') {
      totalRowNumber = r;
      const money = (c) => {
        const v = cell(rows, c, r);
        return typeof v === 'number' ? v : null;
      };
      totalRow = {
        row: r,
        monthlyFee: money('K'),
        discount: money('L'),
        profit: money('M'),
        months: FEES_COLS.map((c, i) => ({ month: monthKey(i), paid: money(c.paid), owed: money(c.owed), paidCell: `${c.paid}${r}` })),
      };
      continue;
    }
    const name = String(cell(rows, 'F', r) || '').trim();
    const id = String(cell(rows, 'E', r) || '').trim().toLowerCase();
    const hasMoney = FEES_COLS.some((c) => rows[r] && (rows[r][c.paid] !== undefined || rows[r][c.owed] !== undefined));
    if (!name && !hasMoney) continue;
    const belowTotal = totalRowNumber !== null && r > totalRowNumber;
    const entry = {
      row: r,
      studentId: id || null,
      name,
      parentEmail: String(cell(rows, 'A', r) || '').trim().toLowerCase() || null,
      monthlyFee: parseMoney(cell(rows, 'K', r)).value,
      discount: parseMoney(cell(rows, 'L', r)).value,
      belowTotal,
      shifted: false,
      months: [],
    };
    // Rows added under the Total row sometimes have payments typed one column
    // to the right, in "Owed". Read those as paid and say so.
    const paidAny = FEES_COLS.some((c) => typeof cell(rows, c.paid, r) === 'number');
    const owedAny = FEES_COLS.some((c) => typeof cell(rows, c.owed, r) === 'number');
    if (belowTotal && !paidAny && owedAny) entry.shifted = true;
    FEES_COLS.forEach((cols, i) => {
      const paidCol = entry.shifted ? cols.owed : cols.paid;
      const owedCol = entry.shifted ? null : cols.owed;
      const paid = parseMoney(cell(rows, paidCol, r));
      const owed = owedCol ? parseMoney(cell(rows, owedCol, r)) : { value: null, issue: null };
      for (const [what, parsed, col] of [['paid', paid, paidCol], ['owed', owed, owedCol]]) {
        if (parsed.issue) {
          flags.push({
            severity: 'warn', kind: 'non_numeric_money', tab: 'Fees', cell: `${col}${r}`, month: monthKey(i),
            message: `${name || '(no name)'}: ${what} ${parsed.issue}`,
          });
        }
      }
      entry.months.push({
        month: monthKey(i),
        paid: paid.value,
        owed: owed.value,
        date: excelDateToIso(cell(rows, cols.date, r)),
        paidCell: `${paidCol}${r}`,
      });
    });
    students.push(entry);
  }
  return { students, totalRow };
}

/* ------------------------------------------------------------------ */
/* Flags                                                               */
/* ------------------------------------------------------------------ */

function addOutlierFlags(flags, label, tab, items) {
  // items: [{ value, cell, month, who }]
  const med = median(items.map((i) => i.value).filter((v) => v > 0));
  if (!med) return;
  for (const it of items) {
    if (it.value > med * 10) {
      flags.push({
        severity: 'error', kind: 'huge_value', tab, cell: it.cell, month: it.month,
        message: `${label}${it.who ? ` (${it.who})` : ''}: ${it.value} is more than 10x the median ${round2(med)}`,
      });
    }
  }
}

function buildFlags({ staff, budget, fees, feesTotal }, flags) {
  // Huge cells
  addOutlierFlags(
    flags, 'Staff amount', 'Staff',
    staff.teachers.flatMap((t) => t.months.filter((m) => m.amount > 0).map((m) => ({
      value: m.amount, cell: m.cells.amount, month: m.month, who: t.sheetName,
    })))
  );
  addOutlierFlags(
    flags, 'Fees paid', 'Fees',
    fees.flatMap((s) => s.months.filter((m) => m.paid > 0).map((m) => ({
      value: m.paid, cell: m.paidCell, month: m.month, who: s.name,
    })))
  );
  addOutlierFlags(
    flags, 'Budget income', 'Budget',
    budget.filter((b) => b.income > 0).map((b) => ({ value: b.income, cell: `H${b.row}`, month: b.month }))
  );
  const incomeMedian = median(budget.map((b) => b.income).filter((v) => v > 0));
  for (const b of budget) {
    if (b.income > 0 && incomeMedian && b.income < incomeMedian / 10) {
      flags.push({
        severity: 'warn', kind: 'tiny_value', tab: 'Budget', cell: `H${b.row}`, month: b.month,
        message: `Budget income ${b.income} is under a tenth of the median ${round2(incomeMedian)}`,
      });
    }
    for (const c of b.textCells) {
      flags.push({
        severity: 'warn', kind: 'non_numeric_money', tab: 'Budget', cell: `${c}${b.row}`, month: b.month,
        message: `Budget cell holds text`,
      });
    }
  }

  // Stated totals vs the rows above them (Staff tab)
  for (let i = 0; i < IMPORT_MONTHS; i++) {
    const summed = round2(staff.teachers.reduce((s, t) => s + (t.months[i].amount || 0), 0));
    const stated = staff.statedTeacherTotals[i];
    if (stated !== null && Math.abs(stated - summed) > 0.5) {
      flags.push({
        severity: 'warn', kind: 'total_mismatch', tab: 'Staff', cell: `${STAFF_COLS[i].amount}${STAFF_TOTAL_ROW}`, month: monthKey(i),
        message: `Teacher total says ${stated}, the rows add up to ${summed}`,
      });
    }
  }
  for (let i = 0; i < 4; i++) {
    const adminSum = staff.admins.reduce((s, a) => s + (a.months[i].amount || 0), 0);
    const costSum = staff.costs.reduce((s, c) => s + (c.months[i].amount || 0), 0);
    const summed = round2(adminSum + costSum);
    const stated = staff.statedAdminTotals[i];
    if (stated !== null && Math.abs(stated - summed) > 0.5) {
      flags.push({
        severity: 'warn', kind: 'total_mismatch', tab: 'Staff', cell: `${STAFF_COLS[i].amount}${ADMIN_TOTAL_ROW}`, month: monthKey(i),
        message: `Administrator and cost total says ${stated}, the rows add up to ${summed}`,
      });
    }
  }

  // Budget vs Staff tab
  for (const b of budget) {
    const i = MONTHS.findIndex((_, idx) => monthKey(idx) === b.month);
    if (i >= IMPORT_MONTHS) continue;
    const summed = round2(staff.teachers.reduce((s, t) => s + (t.months[i].amount || 0), 0));
    if (b.staff !== null && Math.abs(b.staff - summed) > 0.5) {
      flags.push({
        severity: 'warn', kind: 'budget_mismatch', tab: 'Budget', cell: `I${b.row}`, month: b.month,
        message: `Budget staff cost ${b.staff} differs from the Staff tab rows (${summed})`,
      });
    }
    // The sheet's "Other cost" is the Bank line, which its "Administration cost" already includes.
    const bank = staff.costs.find((c) => c.label === 'Bank');
    const bankAmount = bank && i < 4 ? bank.months[i].amount : null;
    if (b.other && bankAmount && Math.abs(b.other - bankAmount) < 0.5 && b.admin >= bankAmount) {
      flags.push({
        severity: 'warn', kind: 'double_count', tab: 'Budget', cell: `K${b.row}`, month: b.month,
        message: `Bank ${bankAmount} is counted in both Administration cost and Other cost, so total cost is ${bankAmount} too high`,
      });
    }
  }

  // Fees tab: the Total row against the rows
  const above = fees.filter((st) => !st.belowTotal);
  const below = fees.filter((st) => st.belowTotal);
  if (below.length) {
    flags.push({
      severity: 'info', kind: 'rows_below_total', tab: 'Fees', cell: `A${feesTotal ? feesTotal.row + 1 : ''}`, month: null,
      message: `${below.length} student rows sit below the Total row, so the sheet's totals leave them out` +
        `${below.some((b) => b.shifted) ? `; ${below.filter((b) => b.shifted).length} of them have payments typed in the Owed column (read as paid here)` : ''}`,
    });
  }
  if (feesTotal) {
    FEES_COLS.forEach((cols, i) => {
      const stated = feesTotal.months[i].paid;
      if (stated === null) return;
      const rowsAbove = round2(above.reduce((sum, st) => sum + (st.months[i].paid || 0), 0));
      const rowsBelow = round2(below.reduce((sum, st) => sum + (st.months[i].paid || 0), 0));
      if (Math.abs(stated - rowsAbove) > 0.5) {
        const huge = stated > Math.max(rowsAbove, 1) * 10;
        flags.push({
          severity: huge ? 'error' : 'warn', kind: huge ? 'huge_value' : 'total_mismatch', tab: 'Fees',
          cell: feesTotal.months[i].paidCell, month: monthKey(i),
          message: `Fees Total says ${stated}; the student rows above it add up to ${rowsAbove}` +
            `${rowsBelow ? ` (and ${rowsBelow} more sits below the Total row)` : ''}`,
        });
      }
    });
    const feeRows = round2(above.reduce((sum, st) => sum + (st.monthlyFee || 0), 0));
    if (feesTotal.monthlyFee !== null && feesTotal.monthlyFee > Math.max(feeRows, 1) * 10) {
      flags.push({
        severity: 'error', kind: 'huge_value', tab: 'Fees', cell: `K${feesTotal.row}`, month: null,
        message: `Monthly fees Total says ${feesTotal.monthlyFee}; the rows add up to ${feeRows}`,
      });
    }
    for (const [label, col, v] of [['Discount', 'L', feesTotal.discount], ['Monthly profit', 'M', feesTotal.profit]]) {
      if (v !== null && v > 1e6) {
        flags.push({
          severity: 'error', kind: 'huge_value', tab: 'Fees', cell: `${col}${feesTotal.row}`, month: null,
          message: `${label} Total is ${v}`,
        });
      }
    }
  }

  // Budget income vs the Fees Total row (what the budget is meant to copy) and the rows
  for (const b of budget) {
    const i = MONTHS.findIndex((_, idx) => monthKey(idx) === b.month);
    if (i >= IMPORT_MONTHS || b.income === null || !feesTotal) continue;
    const stated = feesTotal.months[i].paid;
    const rowsAll = round2(fees.reduce((sum, st) => sum + (st.months[i].paid || 0), 0));
    if (stated !== null && Math.abs(b.income - stated) > 0.5) {
      flags.push({
        severity: 'warn', kind: 'budget_vs_fees', tab: 'Budget', cell: `H${b.row}`, month: b.month,
        message: `Budget income ${b.income} differs from the Fees Total ${stated}`,
      });
    } else if (b.income > 0 && rowsAll > 0 && Math.abs(b.income - rowsAll) / rowsAll > 0.05 && b.income < 1e6) {
      flags.push({
        severity: 'warn', kind: 'budget_vs_fees', tab: 'Budget', cell: `H${b.row}`, month: b.month,
        message: `Budget income ${b.income} vs ${rowsAll} paid across all student rows`,
      });
    }
  }

  // Staff months with almost nothing recorded
  const monthTotals = Array.from({ length: IMPORT_MONTHS }, (_, i) =>
    staff.teachers.reduce((s, t) => s + (t.months[i].amount || 0), 0));
  const med = median(monthTotals);
  monthTotals.forEach((t, i) => {
    if (med && t < med / 4) {
      flags.push({
        severity: 'warn', kind: 'low_month', tab: 'Staff', cell: `${STAFF_COLS[i].amount}${STAFF_TOTAL_ROW}`, month: monthKey(i),
        message: `Only ${round2(t)} recorded in staff payments (median month ${round2(med)}); payments may be missing`,
      });
    }
  });

  // September addendum vs the main grid
  for (const a of staff.septAddendum) {
    const t = staff.teachers.find((x) => nameSimilarity(x.sheetName, a.name) >= 0.8);
    const sep = t && t.months[8].amount;
    if (t && typeof sep === 'number' && Math.abs(sep - a.amount) > 1) {
      flags.push({
        severity: 'info', kind: 'addendum_mismatch', tab: 'Staff', cell: `H${a.row}`, month: '2026-09',
        message: `September list shows ${a.amount} for ${a.name}; the main grid shows ${sep}`,
      });
    }
  }
}

/* ------------------------------------------------------------------ */
/* Firestore (read-only unless --apply)                                */
/* ------------------------------------------------------------------ */

function initFirestore(credentialsPath) {
  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    const file = credentialsPath || process.env.GOOGLE_APPLICATION_CREDENTIALS || DEFAULT_CREDENTIALS;
    admin.initializeApp({ credential: admin.credential.cert(require(file)), projectId: PROJECT_ID });
  }
  return { admin, db: admin.firestore() };
}

async function loadUsers(db) {
  const snap = await db.collection('users').get();
  const users = [];
  snap.forEach((d) => {
    const x = d.data();
    const first = x.first_name || x.firstName || '';
    const last = x.last_name || x.lastName || '';
    const name = (`${first} ${last}`.trim() || x.name || '').trim();
    users.push({
      uid: d.id,
      name,
      type: x.user_type || x.role || null,
      active: x.is_active !== false,
      studentCode: x.student_code ? String(x.student_code).trim().toLowerCase() : null,
    });
  });
  return users;
}

async function loadSeptemberInvoices(db) {
  const seen = new Map();
  for (const field of ['period', 'period_start']) {
    const snap = await db.collection('invoices').where(field, '==', '2026-09').get();
    snap.forEach((d) => seen.set(d.id, d.data()));
  }
  return [...seen.entries()].map(([id, x]) => ({
    id,
    number: x.invoice_number || null,
    status: x.status || null,
    total: Number(x.total_amount) || 0,
    paid: Number(x.paid_amount) || 0,
    parentId: x.parent_id || null,
    studentId: x.student_id || null,
    items: Array.isArray(x.items)
      ? x.items.map((it) => ({ studentId: it.student_id || null, total: Number(it.total) || 0, description: it.description || '' }))
      : [],
  }));
}

async function existingIds(db, collection, ids) {
  const found = new Set();
  for (let i = 0; i < ids.length; i += 200) {
    const refs = ids.slice(i, i + 200).map((id) => db.collection(collection).doc(id));
    if (!refs.length) continue;
    const snaps = await db.getAll(...refs);
    snaps.forEach((s) => s.exists && found.add(s.id));
  }
  return found;
}

/* ------------------------------------------------------------------ */
/* Proposals                                                           */
/* ------------------------------------------------------------------ */

function buildPayoutProposals(staff, users) {
  const teacherPool = users.filter((u) => u.type === 'teacher' || u.type === 'admin');
  const adminPool = users.filter((u) => u.type === 'admin');
  const proposals = [];
  const unmatched = [];
  const possible = [];
  const septUnpaid = [];
  const skippedZero = [];
  const people = [];

  const handle = (sheetName, role, pool, months, extra) => {
    const match = matchPerson(sheetName, pool);
    people.push({ sheetName, role, confidence: match.confidence });
    const record = {
      sheetName,
      role,
      confidence: match.confidence,
      matchedUser: match.user ? { uid: match.user.uid, name: match.user.name, active: match.user.active } : null,
      score: match.score || 0,
      candidates: match.candidates,
    };
    if (match.confidence === 'unmatched') unmatched.push({ ...record, reason: extra.reason || 'no user close to this name' });
    if (match.confidence === 'possible') possible.push(record);

    for (const m of months) {
      const amount = m.amount;
      if (amount === null || amount === undefined) continue;
      const deducted = m.deducted || 0;
      if (m.status && /unpaid/i.test(m.status)) {
        if (amount > 0) septUnpaid.push({ sheetName, month: m.month, amount, deducted, uid: match.user ? match.user.uid : null, confidence: match.confidence });
        continue;
      }
      if (amount === 0 && deducted === 0) {
        skippedZero.push({ sheetName, month: m.month });
        continue;
      }
      const noteParts = [`Imported from the 2026 sheet (${extra.where}).`];
      if (deducted) noteParts.push(`Deducted ${deducted}.`);
      if (m.hours) noteParts.push(`${m.hours} h recorded.`);
      if (m.status) noteParts.push(`Sheet status: ${m.status}.`);
      proposals.push({
        id: match.user ? `${m.month}_${match.user.uid}` : null,
        user_id: match.user && match.confidence !== 'unmatched' ? match.user.uid : null,
        name: match.user && match.confidence !== 'unmatched' ? match.user.name : sheetName,
        sheet_name: sheetName,
        match_confidence: match.confidence,
        role,
        month: m.month,
        amount_due: round2(amount),
        amount_paid: round2(amount),
        date_paid: m.datePaid || null,
        method: extra.method || null,
        transfer_fee: m.transferFee || 0,
        reference: extra.code || null,
        receipt_path: null,
        note: noteParts.join(' '),
        sheet_cell: m.cells ? m.cells.amount : m.cell,
        import_batch: IMPORT_BATCH,
        source: SOURCE,
        apply: false,
      });
    }
  };

  for (const t of staff.teachers) {
    handle(t.sheetName, 'teacher', teacherPool, t.months, {
      where: `Staff tab row ${t.row}`,
      code: t.code,
      method: t.sentTo,
    });
  }
  for (const a of staff.admins) {
    handle(a.sheetName, 'admin', adminPool, a.months, {
      where: `Staff tab row ${a.row}`,
      method: null,
      reason: 'a role title or first name only; needs admin pay terms set by hand',
    });
  }

  // Only high-confidence matches with one doc per person-month are written by --apply.
  const counts = {};
  proposals.forEach((p) => {
    if (p.id) counts[p.id] = (counts[p.id] || 0) + 1;
  });
  proposals.forEach((p) => {
    p.duplicate = !!(p.id && counts[p.id] > 1);
    p.apply = p.match_confidence === 'matched' && !!p.user_id && !p.duplicate && p.amount_paid > 0;
    if (p.duplicate) p.note += ' Two sheet rows match this person and month; review before importing.';
  });
  return { proposals, unmatched, possible, septUnpaid, skippedZero, people };
}

function lastDayOfMonth(month) {
  const [y, m] = month.split('-').map(Number);
  return new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
}

function buildExpenseProposals(staff) {
  const out = [];
  for (const c of staff.costs) {
    for (const m of c.months) {
      if (!m.amount || m.amount <= 0) continue;
      out.push({
        id: `sheet2026_${m.month}_${c.label.toLowerCase().replace(/[^a-z]+/g, '_')}`,
        month: m.month,
        kind: 'one_time',
        category: c.category,
        name: c.label,
        amount: round2(m.amount),
        currency: 'USD',
        expense_date: lastDayOfMonth(m.month),
        note: `Imported from the 2026 sheet (Staff tab ${m.cell}).`,
        notes: `Imported from the 2026 sheet (Staff tab ${m.cell}).`,
        deleted: false,
        source: SOURCE,
        import_batch: IMPORT_BATCH,
        sheet_cell: m.cell,
      });
    }
  }
  return out;
}

/* ------------------------------------------------------------------ */
/* September reconciliation (read-only)                                */
/* ------------------------------------------------------------------ */

function reconcileSeptember(fees, users, invoices) {
  const students = users.filter((u) => u.type === 'student');
  const byCode = new Map(students.filter((s) => s.studentCode).map((s) => [s.studentCode, s]));
  const live = invoices.filter((i) => i.status !== 'cancelled');

  const appByStudent = new Map();
  for (const inv of live) {
    const items = inv.items.length ? inv.items : [{ studentId: inv.studentId, total: inv.total }];
    for (const it of items) {
      const sid = it.studentId || inv.studentId;
      if (!sid) continue;
      const share = inv.total > 0 ? inv.paid * (it.total / inv.total) : 0;
      const cur = appByStudent.get(sid) || { billed: 0, paid: 0, invoices: new Set() };
      cur.billed += it.total;
      cur.paid += Math.min(share, it.total);
      cur.invoices.add(inv.number || inv.id);
      appByStudent.set(sid, cur);
    }
  }

  const rows = [];
  const unmatchedSheet = [];
  const seenUids = new Set();
  let sheetPaidTotal = 0;
  for (const s of fees) {
    const sep = s.months[8];
    if (typeof sep.paid !== 'number' || sep.paid === 0) continue;
    sheetPaidTotal += sep.paid;
    let user = s.studentId ? byCode.get(s.studentId) : null;
    let how = 'student id';
    if (!user && s.name) {
      const m = matchPerson(s.name, students);
      if (m.confidence === 'matched' && m.score >= 0.92) {
        user = m.user;
        how = 'name';
      }
    }
    if (!user) {
      unmatchedSheet.push({ row: s.row, name: s.name || '(no name)', studentId: s.studentId, sheetPaid: sep.paid });
      continue;
    }
    seenUids.add(user.uid);
    const app = appByStudent.get(user.uid) || { billed: 0, paid: 0, invoices: new Set() };
    rows.push({
      row: s.row,
      name: s.name,
      uid: user.uid,
      matchedBy: how,
      sheetPaid: round2(sep.paid),
      appBilled: round2(app.billed),
      appPaid: round2(app.paid),
      difference: round2(sep.paid - app.paid),
      invoices: [...app.invoices],
    });
  }

  const appOnly = [];
  for (const [uid, app] of appByStudent) {
    if (seenUids.has(uid) || app.paid <= 0.005) continue;
    const u = students.find((x) => x.uid === uid);
    appOnly.push({ uid, name: u ? u.name : '(unknown student)', appPaid: round2(app.paid) });
  }

  for (const u of unmatchedSheet) {
    const twin = appOnly.find((a) => nameSimilarity(u.name, a.name) >= 0.95);
    if (twin) u.sameNameInApp = { name: twin.name, appPaid: twin.appPaid };
  }
  const differing = rows.filter((r) => Math.abs(r.difference) >= 0.5);
  return {
    month: '2026-09',
    appInvoices: invoices.length,
    appInvoicesCancelled: invoices.length - live.length,
    sheetStudentsPaid: rows.length + unmatchedSheet.length,
    matched: rows.length,
    unmatchedSheet,
    same: rows.length - differing.length,
    differing,
    sheetPaidMoreCount: differing.filter((r) => r.difference > 0).length,
    appPaidMoreCount: differing.filter((r) => r.difference < 0).length,
    appOnly,
    totals: {
      sheetPaid: round2(sheetPaidTotal),
      sheetPaidMatched: round2(rows.reduce((s, r) => s + r.sheetPaid, 0)),
      appPaidForMatched: round2(rows.reduce((s, r) => s + r.appPaid, 0)),
      appPaidAll: round2([...appByStudent.values()].reduce((s, a) => s + a.paid, 0)),
      appOnlyPaid: round2(appOnly.reduce((s, r) => s + r.appPaid, 0)),
    },
  };
}

/* ------------------------------------------------------------------ */
/* Output                                                              */
/* ------------------------------------------------------------------ */

const usd = (n) => {
  if (n === null || n === undefined) return '-';
  const abs = Math.abs(Number(n)).toLocaleString('en-US', { maximumFractionDigits: 2 });
  return `${Number(n) < 0 ? '-' : ''}$${abs}`;
};

function renderMarkdown(r) {
  const L = [];
  const c = r.counts;
  L.push('# 2026 sheet import - dry run review', '');
  L.push(`Generated ${r.generatedAt}. Nothing was written to Firestore. Workbook: \`${r.workbook}\`.`, '');
  L.push('## Summary', '');
  L.push('| Item | Count |', '|---|---|');
  L.push(`| Staff payout proposals (Jan-Sep) | ${c.payoutProposals} |`);
  L.push(`| ...ready to import (high-confidence match, one per person-month) | ${c.payoutsReady} |`);
  L.push(`| ...need review (possible match, unmatched or duplicate) | ${c.payoutsNeedReview} |`);
  L.push(`| Staff names matched / possible / unmatched | ${c.staffMatched} / ${c.staffPossible} / ${c.staffUnmatched} |`);
  L.push(`| Expense proposals (Jan-Apr line items) | ${c.expenseProposals} |`);
  L.push(`| September amounts still marked Unpaid (not proposed) | ${c.septUnpaid} |`);
  L.push(`| Flags (error / warn / info) | ${c.flagsError} / ${c.flagsWarn} / ${c.flagsInfo} |`);
  if (r.reconciliation) {
    L.push(`| September fees: students compared / same / different | ${r.reconciliation.matched} / ${r.reconciliation.same} / ${r.reconciliation.differing.length} |`);
  }
  L.push('');

  L.push('## Flags', '');
  if (!r.flags.length) L.push('None.', '');
  else {
    L.push('| Severity | Where | Month | What |', '|---|---|---|---|');
    for (const f of r.flags) L.push(`| ${f.severity} | ${f.tab} ${f.cell || ''} | ${f.month || ''} | ${f.message.replace(/\|/g, '/')} |`);
    L.push('');
  }

  L.push('## Staff payouts by month', '');
  L.push('| Month | Proposals | Ready | Total |', '|---|---|---|---|');
  for (const m of r.payoutsByMonth) L.push(`| ${m.month} | ${m.count} | ${m.ready} | ${usd(m.total)} |`);
  L.push('');

  L.push('## Names that need a person', '');
  if (!r.unmatched.length && !r.possible.length) L.push('None.', '');
  if (r.unmatched.length) {
    L.push('Unmatched (no user close enough):', '');
    for (const u of r.unmatched) L.push(`- ${u.sheetName} (${u.role})${u.reason ? ` - ${u.reason}` : ''}`);
    L.push('');
  }
  if (r.possible.length) {
    L.push('Possible matches (not imported until confirmed):', '');
    for (const u of r.possible) {
      L.push(`- ${u.sheetName} (${u.role}): ${u.candidates.map((x) => `${x.name} ${x.score}`).join('; ') || 'no candidate'}`);
    }
    L.push('');
  }

  L.push('## Expense proposals', '');
  if (!r.expenses.length) L.push('None.', '');
  else {
    L.push('| Month | Category | Name | Amount |', '|---|---|---|---|');
    for (const e of r.expenses) L.push(`| ${e.month} | ${e.category} | ${e.name} | ${usd(e.amount)} |`);
    L.push('');
  }

  L.push('## Budget tab vs what the other tabs add up to', '');
  L.push('| Month | Budget income | Fees tab paid | Budget staff | Staff tab total |', '|---|---|---|---|---|');
  for (const b of r.budgetComparison) {
    L.push(`| ${b.month} | ${usd(b.budgetIncome)} | ${usd(b.feesPaid)} | ${usd(b.budgetStaff)} | ${usd(b.staffRows)} |`);
  }
  L.push('');

  L.push('## September amounts marked Unpaid (not proposed as payouts)', '');
  if (!r.septUnpaid.length) L.push('None.', '');
  else {
    L.push('| Name | Amount | Deducted | Matched |', '|---|---|---|---|');
    for (const u of r.septUnpaid) L.push(`| ${u.sheetName} | ${usd(u.amount)} | ${usd(u.deducted)} | ${u.confidence} |`);
    L.push('');
  }

  L.push('## Reconciliation: September fees, sheet vs app invoices', '');
  const rec = r.reconciliation;
  if (!rec) L.push('Skipped (--no-firestore).', '');
  else {
    L.push(`The app has ${rec.appInvoices} invoices for 2026-09 (${rec.appInvoicesCancelled} cancelled). The sheet shows ${rec.sheetStudentsPaid} students with a September payment.`, '');
    L.push('| | Count | Amount |', '|---|---|---|');
    L.push(`| Students compared | ${rec.matched} | sheet ${usd(rec.totals.sheetPaidMatched)} / app ${usd(rec.totals.appPaidForMatched)} |`);
    L.push(`| Same paid amount | ${rec.same} | |`);
    L.push(`| Sheet paid more than the app | ${rec.sheetPaidMoreCount} | |`);
    L.push(`| App paid more than the sheet | ${rec.appPaidMoreCount} | |`);
    L.push(`| Sheet students not found in the app | ${rec.unmatchedSheet.length} | ${usd(rec.unmatchedSheet.reduce((s, x) => s + x.sheetPaid, 0))} |`);
    L.push(`| Paid in the app, not in the sheet | ${rec.appOnly.length} | ${usd(rec.totals.appOnlyPaid)} |`);
    L.push('');
    if (rec.differing.length) {
      L.push('Differences (sheet paid vs app paid):', '');
      L.push('| Student | Sheet | App | Difference | Invoices |', '|---|---|---|---|---|');
      for (const d of rec.differing.slice(0, 60)) {
        L.push(`| ${d.name} | ${usd(d.sheetPaid)} | ${usd(d.appPaid)} | ${usd(d.difference)} | ${d.invoices.join(', ') || 'none'} |`);
      }
      if (rec.differing.length > 60) L.push('', `...and ${rec.differing.length - 60} more in the JSON file.`);
      L.push('');
    }
    if (rec.unmatchedSheet.length) {
      L.push('Sheet rows with a September payment and no matching student:', '');
      for (const u of rec.unmatchedSheet.slice(0, 40)) {
        L.push(`- row ${u.row}: ${u.name} (${u.studentId || 'no id'}) ${usd(u.sheetPaid)}${u.sameNameInApp ? ` - same name in the app with ${usd(u.sameNameInApp.appPaid)} paid (student id differs)` : ''}`);
      }
      L.push('');
    }
    if (rec.appOnly.length) {
      L.push('Paid in the app, not on the sheet:', '');
      for (const u of rec.appOnly.slice(0, 40)) L.push(`- ${u.name} ${usd(u.appPaid)}`);
      L.push('');
    }
  }

  L.push('## How to read this', '');
  L.push('- A sheet month column is taken as the payout `month` (the month the hours belong to).');
  L.push('- Staff amounts on the sheet are treated as paid; `amount_due` equals `amount_paid`; a "Deducted" value goes into the note. Date paid is empty on the sheet, so `date_paid` is null.');
  L.push('- September rows marked Unpaid are not payouts; they stay due in the app.');
  L.push('- Administrator rows are proposed only for Jan-Apr (the only months filled). Role titles (CEO, CTO...) cannot be matched to a person.');
  L.push('- Expenses come from the five cost lines (Jan-Apr). Administrator pay is not an expense (the app computes it). Bank maps to Other, Internet and Coding subscriptions to Software.');
  L.push('- `--apply --yes` writes only the "ready" payouts and all expense proposals, tagged `import_batch: sheet-2026`.');
  return L.join('\n') + '\n';
}

/* ------------------------------------------------------------------ */
/* Apply / remove                                                      */
/* ------------------------------------------------------------------ */

async function applyImport(review, ctx) {
  const { admin, db } = ctx;
  const Timestamp = admin.firestore.Timestamp;
  const now = Timestamp.now();
  const by = 'sheet-import-2026';
  const ops = [];

  for (const p of review.payouts.filter((x) => x.apply)) {
    ops.push({
      ref: db.collection('staff_payouts').doc(p.id),
      data: {
        user_id: p.user_id,
        name: p.name,
        role: p.role,
        month: p.month,
        amount_due: p.amount_due,
        amount_paid: p.amount_paid,
        date_paid: p.date_paid ? Timestamp.fromDate(new Date(`${p.date_paid}T12:00:00Z`)) : null,
        method: p.method,
        transfer_fee: p.transfer_fee,
        reference: p.reference,
        receipt_path: null,
        note: p.note,
        recorded_at: now,
        recorded_by: by,
        voided: false,
        history: [{ action: 'imported', at: now, by, note: `Sheet cell ${p.sheet_cell}` }],
        source: SOURCE,
        import_batch: IMPORT_BATCH,
      },
    });
  }
  for (const e of review.expenses) {
    ops.push({
      ref: db.collection('finance_expenses').doc(e.id),
      data: {
        month: e.month,
        kind: e.kind,
        category: e.category,
        name: e.name,
        amount: e.amount,
        currency: e.currency,
        expense_date: Timestamp.fromDate(new Date(`${e.expense_date}T12:00:00Z`)),
        note: e.note,
        notes: e.notes,
        deleted: false,
        created_at: now,
        created_by: by,
        source: SOURCE,
        import_batch: IMPORT_BATCH,
      },
    });
  }

  let written = 0;
  let skipped = 0;
  for (let i = 0; i < ops.length; i += 400) {
    const batch = db.batch();
    const chunk = ops.slice(i, i + 400);
    const exists = await db.getAll(...chunk.map((o) => o.ref));
    chunk.forEach((o, idx) => {
      if (exists[idx].exists) {
        skipped++;
        return;
      }
      batch.create(o.ref, o.data);
      written++;
    });
    await batch.commit();
  }
  console.log(`Applied: ${written} written, ${skipped} skipped because the doc already exists.`);
}

async function removeBatch({ db }, confirmed) {
  for (const collection of ['staff_payouts', 'finance_expenses']) {
    const snap = await db.collection(collection).where('import_batch', '==', IMPORT_BATCH).get();
    console.log(`${collection}: ${snap.size} docs tagged ${IMPORT_BATCH}`);
    if (!confirmed) continue;
    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      snap.docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
  }
  if (!confirmed) console.log('Nothing deleted. Add --yes to delete.');
}

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */

function parseArgs(argv) {
  const args = { file: DEFAULT_FILE, outDir: DEFAULT_OUT, credentials: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--apply') args.apply = true;
    else if (a === '--yes') args.yes = true;
    else if (a === '--no-firestore') args.noFirestore = true;
    else if (a === '--remove-batch') args.removeBatch = true;
    else if (a === '--file') args.file = argv[++i];
    else if (a === '--out-dir') args.outDir = argv[++i];
    else if (a === '--credentials') args.credentials = argv[++i];
    else throw new Error(`Unknown option ${a}`);
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.removeBatch) {
    await removeBatch(initFirestore(args.credentials), !!args.yes);
    return;
  }
  if (args.apply && !args.yes) {
    throw new Error('--apply writes to production. Re-run with --apply --yes after reading the review.');
  }
  if (args.apply && args.noFirestore) throw new Error('--apply needs Firestore; drop --no-firestore.');

  const shared = readSharedStrings(args.file);
  const sheetIndex = readSheetIndex(args.file);
  const find = (re) => {
    const s = sheetIndex.find((x) => re.test(x.name));
    if (!s) throw new Error(`Tab not found: ${re}. Tabs: ${sheetIndex.map((x) => x.name).join(' | ')}`);
    return readSheet(args.file, s.number, shared);
  };
  const flags = [];
  const staff = parseStaffTab(find(/completed Staff Payment/i), flags);
  const { students: fees, totalRow: feesTotal } = parseFeesTab(find(/2026\s*-?\s*Fees Payment/i), flags);
  const budget = parseBudgetTab(find(/^Budget\s*'?24/i));

  buildFlags({ staff, budget, fees, feesTotal }, flags);

  let users = [];
  let invoices = [];
  let ctx = null;
  if (!args.noFirestore) {
    ctx = initFirestore(args.credentials);
    users = await loadUsers(ctx.db);
    invoices = await loadSeptemberInvoices(ctx.db);
  }

  const { proposals, unmatched, possible, septUnpaid, skippedZero, people } = buildPayoutProposals(staff, users);
  const expenses = buildExpenseProposals(staff);

  if (ctx) {
    const have = await existingIds(ctx.db, 'staff_payouts', proposals.filter((p) => p.id).map((p) => p.id));
    proposals.forEach((p) => {
      if (p.id && have.has(p.id)) {
        p.apply = false;
        p.already_exists = true;
      }
    });
  }

  const reconciliation = ctx ? reconcileSeptember(fees, users, invoices) : null;

  const payoutsByMonth = Array.from({ length: IMPORT_MONTHS }, (_, i) => {
    const rows = proposals.filter((p) => p.month === monthKey(i));
    return {
      month: monthKey(i),
      count: rows.length,
      ready: rows.filter((p) => p.apply).length,
      total: round2(rows.reduce((s, p) => s + p.amount_paid, 0)),
    };
  });

  const budgetComparison = budget.slice(0, IMPORT_MONTHS).map((b, i) => ({
    month: b.month,
    budgetIncome: b.income,
    feesPaid: round2(fees.reduce((s, st) => s + (st.months[i].paid || 0), 0)),
    budgetStaff: b.staff,
    staffRows: round2(staff.teachers.reduce((s, t) => s + (t.months[i].amount || 0), 0)),
  }));

  const sevOrder = { error: 0, warn: 1, info: 2 };
  flags.sort((a, b) => sevOrder[a.severity] - sevOrder[b.severity] || String(a.month).localeCompare(String(b.month)));

  const review = {
    generatedAt: new Date().toISOString(),
    workbook: args.file,
    importBatch: IMPORT_BATCH,
    dryRun: !args.apply,
    counts: {
      payoutProposals: proposals.length,
      payoutsReady: proposals.filter((p) => p.apply).length,
      payoutsNeedReview: proposals.filter((p) => !p.apply).length,
      staffMatched: people.filter((x) => x.confidence === 'matched').length,
      staffPossible: people.filter((x) => x.confidence === 'possible').length,
      staffUnmatched: people.filter((x) => x.confidence === 'unmatched').length,
      staffNames: people.length,
      expenseProposals: expenses.length,
      septUnpaid: septUnpaid.length,
      skippedZero: skippedZero.length,
      flagsError: flags.filter((f) => f.severity === 'error').length,
      flagsWarn: flags.filter((f) => f.severity === 'warn').length,
      flagsInfo: flags.filter((f) => f.severity === 'info').length,
    },
    payoutsByMonth,
    payouts: proposals,
    unmatched,
    possible,
    expenses,
    septUnpaid,
    budget,
    budgetComparison,
    flags,
    reconciliation,
  };

  fs.mkdirSync(args.outDir, { recursive: true });
  const jsonPath = path.join(args.outDir, 'sheet-import-2026-review.json');
  const mdPath = path.join(args.outDir, 'sheet-import-2026-review.md');
  fs.writeFileSync(jsonPath, JSON.stringify(review, null, 2));
  fs.writeFileSync(mdPath, renderMarkdown(review));
  console.log(JSON.stringify({ counts: review.counts, payoutsByMonth, reconciliation: reconciliation && {
    matched: reconciliation.matched, same: reconciliation.same, differing: reconciliation.differing.length,
    sheetPaidMore: reconciliation.sheetPaidMoreCount, appPaidMore: reconciliation.appPaidMoreCount,
    unmatchedSheet: reconciliation.unmatchedSheet.length, appOnly: reconciliation.appOnly.length, totals: reconciliation.totals,
  } }, null, 2));
  console.log(`\nWrote ${jsonPath}\nWrote ${mdPath}`);

  if (args.apply) await applyImport(review, ctx);
  else console.log('\nDry run: nothing was written to Firestore.');
}

if (require.main === module) {
  main().then(() => process.exit(0)).catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
}

module.exports = {
  readSharedStrings,
  readSheetIndex,
  readSheet,
  parseMoney,
  parseHours,
  excelDateToIso,
  normalizeName,
  nameSimilarity,
  matchPerson,
  median,
  stripPhone,
  FEES_COLS,
};
