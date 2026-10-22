/**
 * A small in-memory Firestore for handler tests: collections, documents,
 * where/orderBy/limit, dotted-path updates, transactions, getAll and the
 * FieldValue sentinels the finance handlers use. Not a general double; it
 * implements only what these handlers call.
 */

const isPlain = (v) => v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date) && !v.__op;

const FieldValue = {
  serverTimestamp: () => ({__op: 'serverTimestamp'}),
  arrayUnion: (...elements) => ({__op: 'arrayUnion', elements}),
  delete: () => ({__op: 'delete'}),
  increment: (n) => ({__op: 'increment', n}),
};
const Timestamp = {
  fromDate: (date) => ({__type: 'timestamp', date, toDate: () => date}),
  now: () => Timestamp.fromDate(new Date()),
};

const clone = (v) => {
  if (v instanceof Date) return new Date(v.getTime());
  if (Array.isArray(v)) return v.map(clone);
  if (isPlain(v)) return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, clone(x)]));
  return v;
};

const getPath = (obj, path) => path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);

const setPath = (obj, path, value, now) => {
  const keys = path.split('.');
  let node = obj;
  for (const key of keys.slice(0, -1)) {
    if (!isPlain(node[key])) node[key] = {};
    node = node[key];
  }
  const last = keys[keys.length - 1];
  node[last] = resolve(value, node[last], now);
  if (node[last] === undefined) delete node[last];
};

const resolve = (value, current, now) => {
  if (value && value.__op === 'serverTimestamp') return new Date(now());
  if (value && value.__op === 'arrayUnion') return [...(Array.isArray(current) ? current : []), ...value.elements.map(clone)];
  if (value && value.__op === 'increment') return (Number(current) || 0) + value.n;
  if (value && value.__op === 'delete') return undefined;
  if (isPlain(value)) return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, resolve(v, undefined, now)]).filter(([, v]) => v !== undefined));
  if (Array.isArray(value)) return value.map((v) => resolve(v, undefined, now));
  return clone(value);
};

const deepMerge = (target, source, now) => {
  for (const [k, v] of Object.entries(source)) {
    if (isPlain(v) && isPlain(target[k])) deepMerge(target[k], v, now);
    else {
      const r = resolve(v, target[k], now);
      if (r === undefined) delete target[k];
      else target[k] = r;
    }
  }
  return target;
};

const compare = (a, b) => {
  const av = a instanceof Date ? a.getTime() : a;
  const bv = b instanceof Date ? b.getTime() : b;
  return av < bv ? -1 : av > bv ? 1 : 0;
};

const ops = {
  '==': (a, b) => compare(a, b) === 0 && (a === undefined) === (b === undefined),
  '!=': (a, b) => compare(a, b) !== 0,
  '>': (a, b) => a !== undefined && compare(a, b) > 0,
  '>=': (a, b) => a !== undefined && compare(a, b) >= 0,
  '<': (a, b) => a !== undefined && compare(a, b) < 0,
  '<=': (a, b) => a !== undefined && compare(a, b) <= 0,
  in: (a, list) => list.some((x) => compare(a, x) === 0 && a !== undefined),
  'array-contains': (a, b) => Array.isArray(a) && a.some((x) => compare(x, b) === 0),
};

class FakeFirestore {
  constructor(seed = {}, {now = () => Date.now()} = {}) {
    this.cols = new Map();
    this.now = now;
    this.writes = [];
    for (const [col, docs] of Object.entries(seed)) {
      for (const [id, data] of Object.entries(docs)) this.col(col).set(id, clone(data));
    }
  }

  col(name) {
    if (!this.cols.has(name)) this.cols.set(name, new Map());
    return this.cols.get(name);
  }

  collection(name) {
    return new Query(this, name, [], null, null);
  }

  get(col, id) {
    return this.col(col).get(id);
  }

  async getAll(...refs) {
    return refs.map((r) => r.snap());
  }

  async runTransaction(fn) {
    const tx = {
      get: async (ref) => ref.get(),
      set: (ref, data, opts) => ref.set(data, opts),
      update: (ref, data) => ref.update(data),
      delete: (ref) => ref.delete(),
    };
    return fn(tx);
  }

  batch() {
    const queued = [];
    return {
      set: (ref, data, opts) => queued.push(() => ref.set(data, opts)),
      update: (ref, data) => queued.push(() => ref.update(data)),
      delete: (ref) => queued.push(() => ref.delete()),
      commit: async () => {
        for (const q of queued) await q();
      },
    };
  }

  /** Test helper: current stored copy of a document or undefined. */
  peek(col, id) {
    const v = this.col(col).get(id);
    return v === undefined ? undefined : clone(v);
  }

  all(col) {
    return Object.fromEntries([...this.col(col).entries()].map(([k, v]) => [k, clone(v)]));
  }
}

class DocRef {
  constructor(db, col, id) {
    this.db = db;
    this.col = col;
    this.id = id;
    this.path = `${col}/${id}`;
  }

  snap() {
    const data = this.db.get(this.col, this.id);
    const ref = this;
    return {id: this.id, ref, exists: data !== undefined, data: () => (data === undefined ? undefined : clone(data))};
  }

  async get() {
    return this.snap();
  }

  async create(data) {
    if (this.db.get(this.col, this.id) !== undefined) {
      const err = new Error(`ALREADY_EXISTS: ${this.path}`);
      err.code = 6;
      throw err;
    }
    return this.set(data);
  }

  async set(data, opts = {}) {
    const store = this.db.col(this.col);
    if (opts.merge && store.has(this.id)) {
      deepMerge(store.get(this.id), data, this.db.now);
    } else {
      store.set(this.id, resolve(data, undefined, this.db.now));
    }
    this.db.writes.push({op: 'set', path: this.path});
  }

  async update(data) {
    const store = this.db.col(this.col);
    if (!store.has(this.id)) {
      const err = new Error(`NOT_FOUND: ${this.path}`);
      err.code = 5;
      throw err;
    }
    const doc = store.get(this.id);
    for (const [path, value] of Object.entries(data)) setPath(doc, path, value, this.db.now);
    this.db.writes.push({op: 'update', path: this.path});
  }

  async delete() {
    this.db.col(this.col).delete(this.id);
    this.db.writes.push({op: 'delete', path: this.path});
  }
}

class Query {
  constructor(db, col, filters, order, max) {
    this.db = db;
    this.colName = col;
    this.filters = filters;
    this.order = order;
    this.max = max;
  }

  doc(id) {
    return new DocRef(this.db, this.colName, id || `auto_${Math.random().toString(36).slice(2, 10)}`);
  }

  async add(data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }

  where(field, op, value) {
    return new Query(this.db, this.colName, [...this.filters, {field, op, value}], this.order, this.max);
  }

  orderBy(field, dir = 'asc') {
    return new Query(this.db, this.colName, this.filters, {field, dir}, this.max);
  }

  limit(n) {
    return new Query(this.db, this.colName, this.filters, this.order, n);
  }

  async get() {
    let rows = [...this.db.col(this.colName).entries()].filter(([, data]) =>
      this.filters.every((f) => ops[f.op](getPath(data, f.field), f.value)));
    if (this.order) {
      const {field, dir} = this.order;
      rows.sort((a, b) => compare(getPath(a[1], field), getPath(b[1], field)) * (dir === 'desc' ? -1 : 1));
    }
    if (this.max != null) rows = rows.slice(0, this.max);
    const docs = rows.map(([id]) => new DocRef(this.db, this.colName, id).snap());
    return {docs, empty: docs.length === 0, size: docs.length, forEach: (fn) => docs.forEach(fn)};
  }
}

// Query objects double as collection refs; give them the doc-level helpers.
FakeFirestore.prototype.collection = function collection(name) {
  return new Query(this, name, [], null, null);
};

const install = (admin, seed, opts) => {
  const fake = new FakeFirestore(seed, opts);
  admin.firestore = jest.fn(() => fake);
  admin.firestore.FieldValue = FieldValue;
  admin.firestore.Timestamp = Timestamp;
  return fake;
};

module.exports = {FakeFirestore, FieldValue, Timestamp, install};
