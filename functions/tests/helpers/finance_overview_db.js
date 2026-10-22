/**
 * A small in-memory Firestore for the finance overview tests: collections of
 * documents, equality / range / `in` queries, merge writes, the sentinels the
 * handlers use (arrayUnion, delete) and transactions.
 */

class FakeTimestamp {
  constructor(ms) {
    this.ms = ms;
  }
  toDate() {
    return new Date(this.ms);
  }
  static fromDate(date) {
    return new FakeTimestamp(date.getTime());
  }
  static now() {
    return new FakeTimestamp(FakeTimestamp.nowMs);
  }
}
FakeTimestamp.nowMs = Date.parse('2026-10-22T16:00:00Z');

const FieldValue = {
  arrayUnion: (...elements) => ({__op: 'arrayUnion', elements}),
  delete: () => ({__op: 'delete'}),
  serverTimestamp: () => ({__op: 'serverTimestamp'}),
};

const isOp = (v) => v && typeof v === 'object' && typeof v.__op === 'string';

const clone = (value) => {
  if (value instanceof Date) return new Date(value.getTime());
  if (value instanceof FakeTimestamp) return new FakeTimestamp(value.ms);
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = clone(v);
    return out;
  }
  return value;
};

/** Milliseconds for time-like values, so Dates and Timestamps compare with each other. */
const timeOf = (v) => {
  if (v instanceof Date) return v.getTime();
  if (v instanceof FakeTimestamp) return v.ms;
  return null;
};

const compare = (a, op, b) => {
  const ta = timeOf(a);
  const tb = timeOf(b);
  let x = a;
  let y = b;
  if (ta !== null || tb !== null) {
    if (ta === null || tb === null) return false;
    x = ta;
    y = tb;
  } else if (typeof a !== typeof b) {
    return false;
  }
  switch (op) {
    case '==': return x === y;
    case '<': return x < y;
    case '<=': return x <= y;
    case '>': return x > y;
    case '>=': return x >= y;
    default: throw new Error(`unsupported operator ${op}`);
  }
};

const getPath = (obj, path) => path.split('.').reduce((node, key) => (node == null ? undefined : node[key]), obj);

const applyWrite = (base, data, merge) => {
  const out = merge ? clone(base || {}) : {};
  for (const [key, value] of Object.entries(data)) {
    if (isOp(value) && value.__op === 'delete') {
      delete out[key];
    } else if (isOp(value) && value.__op === 'arrayUnion') {
      out[key] = [...(out[key] || []), ...clone(value.elements)];
    } else if (isOp(value) && value.__op === 'serverTimestamp') {
      out[key] = FakeTimestamp.now();
    } else {
      out[key] = clone(value);
    }
  }
  return out;
};

function makeDb(seed = {}) {
  const store = {};
  for (const [name, docs] of Object.entries(seed)) store[name] = clone(docs);
  const reads = [];

  const snapOf = (name, id) => {
    const data = store[name] && store[name][id];
    return {
      id,
      exists: data !== undefined,
      data: () => (data === undefined ? undefined : clone(data)),
    };
  };

  const docRef = (name, id) => ({
    id,
    path: `${name}/${id}`,
    get: async () => {
      reads.push(`${name}/${id}`);
      return snapOf(name, id);
    },
    set: async (data, options) => {
      store[name] = store[name] || {};
      store[name][id] = applyWrite(store[name][id], data, Boolean(options && options.merge));
    },
    update: async (data) => {
      if (!store[name] || store[name][id] === undefined) throw new Error(`no document ${name}/${id}`);
      store[name][id] = applyWrite(store[name][id], data, true);
    },
  });

  const query = (name, filters = [], max = Infinity, fields = null) => ({
    where: (field, op, value) => query(name, [...filters, {field, op, value}], max, fields),
    limit: (n) => query(name, filters, n, fields),
    select: (...names) => query(name, filters, max, names),
    get: async () => {
      const docs = Object.entries(store[name] || {})
        .filter(([, data]) =>
          filters.every(({field, op, value}) => {
            const actual = getPath(data, field);
            if (op === 'in') return Array.isArray(value) && value.length <= 30 && value.includes(actual);
            return actual !== undefined && compare(actual, op, value);
          })
        )
        .slice(0, max)
        .map(([id]) => {
          reads.push(`${name}/${id}`);
          const snap = snapOf(name, id);
          if (!fields) return snap;
          const full = snap.data();
          const picked = Object.fromEntries(fields.filter((f) => full[f] !== undefined).map((f) => [f, full[f]]));
          return {...snap, data: () => clone(picked)};
        });
      return {docs, size: docs.length, empty: docs.length === 0};
    },
  });

  return {
    store,
    reads,
    collection: (name) => ({
      doc: (id) => docRef(name, id),
      where: (field, op, value) => query(name, [{field, op, value}]),
      limit: (n) => query(name, [], n),
      select: (...names) => query(name, [], Infinity, names),
      get: () => query(name).get(),
    }),
    runTransaction: async (fn) => {
      const tx = {
        get: (ref) => ref.get(),
        set: (ref, data, options) => ref.set(data, options),
        update: (ref, data) => ref.update(data),
      };
      return fn(tx);
    },
  };
}

module.exports = {makeDb, FakeTimestamp, FieldValue};
