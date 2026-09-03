/**
 * A minimal .xlsx writer.
 *
 * An xlsx is a zip of XML parts. Writing those directly is a few hundred lines
 * and no dependency; the alternative on npm is `xlsx@0.18.5`, whose published
 * advisories are only fixed in builds distributed outside the registry. This
 * app exports student and family records, so a permanent known-vulnerable
 * dependency in that path is not a good trade for code we can read.
 *
 * Entries are stored uncompressed (ZIP method 0). Export files are small, and
 * STORE needs no DEFLATE implementation to go wrong.
 */

export type CellValue = string | number | null | undefined;

export type Sheet = {
  /** Trimmed to Excel's 31-character limit, with its illegal characters removed. */
  name: string;
  headers: string[];
  rows: CellValue[][];
};

/* ------------------------------------------------------------------ zip -- */

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[i] = c >>> 0;
  }
  return table;
})();

const crc32 = (bytes: Uint8Array): number => {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) crc = CRC_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
};

const encode = (text: string): Uint8Array => new TextEncoder().encode(text);

/** MS-DOS date/time. Fixed, so the same data always produces the same file. */
const DOS_TIME = 0;
const DOS_DATE = ((2020 - 1980) << 9) | (1 << 5) | 1;

export const zipParts = (files: { name: string; content: string }[]): Uint8Array => {
  const entries = files.map((file) => {
    const data = encode(file.content);
    return { name: file.name, data, crc: crc32(data) };
  });

  const chunks: Uint8Array[] = [];
  const offsets: number[] = [];
  let offset = 0;

  const push = (bytes: Uint8Array) => {
    chunks.push(bytes);
    offset += bytes.length;
  };

  const header = (size: number) => {
    const buffer = new ArrayBuffer(size);
    return { view: new DataView(buffer), bytes: new Uint8Array(buffer) };
  };

  for (const entry of entries) {
    const name = encode(entry.name);
    offsets.push(offset);
    const { view, bytes } = header(30);
    view.setUint32(0, 0x04034b50, true);
    view.setUint16(4, 20, true);
    view.setUint16(6, 0, true);
    view.setUint16(8, 0, true); // method: stored
    view.setUint16(10, DOS_TIME, true);
    view.setUint16(12, DOS_DATE, true);
    view.setUint32(14, entry.crc, true);
    view.setUint32(18, entry.data.length, true);
    view.setUint32(22, entry.data.length, true);
    view.setUint16(26, name.length, true);
    view.setUint16(28, 0, true);
    push(bytes);
    push(name);
    push(entry.data);
  }

  const directoryStart = offset;
  entries.forEach((entry, index) => {
    const name = encode(entry.name);
    const { view, bytes } = header(46);
    view.setUint32(0, 0x02014b50, true);
    view.setUint16(4, 20, true);
    view.setUint16(6, 20, true);
    view.setUint16(8, 0, true);
    view.setUint16(10, 0, true);
    view.setUint16(12, DOS_TIME, true);
    view.setUint16(14, DOS_DATE, true);
    view.setUint32(16, entry.crc, true);
    view.setUint32(20, entry.data.length, true);
    view.setUint32(24, entry.data.length, true);
    view.setUint16(28, name.length, true);
    view.setUint16(30, 0, true);
    view.setUint16(32, 0, true);
    view.setUint16(34, 0, true);
    view.setUint16(36, 0, true);
    view.setUint32(38, 0, true);
    view.setUint32(42, offsets[index], true);
    push(bytes);
    push(name);
  });

  const { view, bytes } = header(22);
  view.setUint32(0, 0x06054b50, true);
  view.setUint16(8, entries.length, true);
  view.setUint16(10, entries.length, true);
  view.setUint32(12, offset - directoryStart, true);
  view.setUint32(16, directoryStart, true);
  push(bytes);

  const output = new Uint8Array(offset);
  let cursor = 0;
  for (const chunk of chunks) {
    output.set(chunk, cursor);
    cursor += chunk.length;
  }
  return output;
};

/* ------------------------------------------------------------------ xml -- */

/**
 * Control characters are illegal in XML 1.0 and make Excel reject the whole
 * file; one stray character in a free-text note must not lose the export.
 */
const ILLEGAL_XML = /[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g;

export const escapeXml = (value: string): string =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;")
    .replace(ILLEGAL_XML, "");

/** 0 -> A, 25 -> Z, 26 -> AA. */
export const columnName = (index: number): string => {
  let name = "";
  let n = index;
  while (n >= 0) {
    name = String.fromCharCode(65 + (n % 26)) + name;
    n = Math.floor(n / 26) - 1;
  }
  return name;
};

/** Excel forbids these in a sheet name, and caps it at 31 characters. */
export const safeSheetName = (name: string): string => {
  const cleaned = name.replace(/[[\]:*?/\\]/g, " ").trim();
  return (cleaned || "Sheet").slice(0, 31);
};

const cellXml = (value: CellValue, ref: string): string => {
  if (value === null || value === undefined || value === "") return "";
  if (typeof value === "number" && Number.isFinite(value)) {
    return `<c r="${ref}"><v>${value}</v></c>`;
  }
  return `<c r="${ref}" t="inlineStr"><is><t xml:space="preserve">${escapeXml(String(value))}</t></is></c>`;
};

/** Wide enough to read, capped so one long note cannot push a column off screen. */
const columnWidths = (sheet: Sheet): number[] =>
  sheet.headers.map((header, column) => {
    let widest = header.length;
    for (const row of sheet.rows) {
      const value = row[column];
      if (value === null || value === undefined) continue;
      widest = Math.max(widest, String(value).length);
    }
    return Math.min(Math.max(widest + 2, 8), 60);
  });

const sheetXml = (sheet: Sheet): string => {
  const cols = columnWidths(sheet)
    .map((width, index) => `<col min="${index + 1}" max="${index + 1}" width="${width}" customWidth="1"/>`)
    .join("");

  const headerRow = `<row r="1">${sheet.headers
    .map((header, index) => cellXml(header, `${columnName(index)}1`))
    .join("")}</row>`;

  const bodyRows = sheet.rows
    .map((row, rowIndex) => {
      const number = rowIndex + 2;
      const cells = sheet.headers
        .map((_, columnIndex) => cellXml(row[columnIndex], `${columnName(columnIndex)}${number}`))
        .join("");
      return `<row r="${number}">${cells}</row>`;
    })
    .join("");

  const lastColumn = columnName(Math.max(sheet.headers.length - 1, 0));
  const dimension = `A1:${lastColumn}${sheet.rows.length + 1}`;

  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="${dimension}"/><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><sheetFormatPr defaultRowHeight="15"/><cols>${cols}</cols><sheetData>${headerRow}${bodyRows}</sheetData><autoFilter ref="${dimension}"/></worksheet>`;
};

/* ------------------------------------------------------------- workbook -- */

export const workbookParts = (sheets: Sheet[]): { name: string; content: string }[] => {
  const used = new Set<string>();
  const named = sheets.map((sheet, index) => {
    const base = safeSheetName(sheet.name);
    let name = base;
    // Two sheets sharing a name make the file unreadable.
    let suffix = 2;
    while (used.has(name.toLowerCase())) name = `${base.slice(0, 28)} ${suffix++}`;
    used.add(name.toLowerCase());
    return { ...sheet, name, id: index + 1 };
  });

  const overrides = named
    .map(
      (sheet) =>
        `<Override PartName="/xl/worksheets/sheet${sheet.id}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`,
    )
    .join("");

  return [
    {
      name: "[Content_Types].xml",
      content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>${overrides}</Types>`,
    },
    {
      name: "_rels/.rels",
      content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
    },
    {
      name: "xl/workbook.xml",
      content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${named
        .map((sheet) => `<sheet name="${escapeXml(sheet.name)}" sheetId="${sheet.id}" r:id="rId${sheet.id}"/>`)
        .join("")}</sheets></workbook>`,
    },
    {
      name: "xl/_rels/workbook.xml.rels",
      content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${named
        .map(
          (sheet) =>
            `<Relationship Id="rId${sheet.id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${sheet.id}.xml"/>`,
        )
        .join("")}</Relationships>`,
    },
    ...named.map((sheet) => ({
      name: `xl/worksheets/sheet${sheet.id}.xml`,
      content: sheetXml(sheet),
    })),
  ];
};

export const buildWorkbook = (sheets: Sheet[]): Uint8Array => zipParts(workbookParts(sheets));

export const downloadWorkbook = (sheets: Sheet[], fileName: string): void => {
  const blob = new Blob([buildWorkbook(sheets) as BlobPart], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
};
