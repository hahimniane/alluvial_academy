/**
 * A small in-memory Firestore for the finance tests.
 *
 * Supports what the billing engine uses: collection/doc refs, get/set(merge)/
 * update(dotted paths)/delete/add, where() with the usual operators, orderBy,
 * limit, getAll, batches and transactions (buffered writes, reads after a
 * write throw like the real thing), plus FieldValue sentinels and a Timestamp.
 *
 * `db.writes` records every committed write as {op, path} so tests can assert
 * "wrote nothing".
 */

class FakeTimestamp {
  constructor(date) {
    this._date = date;
  }
  static fromDate(date) {
    return new FakeTimestamp(date);
  }
  static fromMillis(ms) {
    return new FakeTimestamp(new Date(ms));
  }
  static now() {
    return new FakeTimestamp(new Date());
  }
  toDate() {
    return this._date;
  }
  toMillis() {
    return this._date.getTime();
  }
  get seconds() {
    return Math.floor(this._date.getTime() / 1000);
  }
  get nanoseconds() {
    return 0;
  }
}

const FieldValue = {
  serverTimestamp: () => ({__op: 'serverTimestamp'}),
  delete: () => ({__op: 'delete'}),
  arrayUnion: (...elements) => ({__op: 'arrayUnion', elements}),
  arrayRemove: (...elements) => ({__op: 'arrayRemove', elements}),
  increment: (n) => ({__op: 'increment', n}),
};

const isSentinel = (v) => v && typeof v === 'object' && typeof v.__op === 'string';
const isPlain = (v) =>
  v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date) && !(v instanceof FakeTimestamp) && !isSentinel(v);

const clone = (value) => {
  if (value instanceof FakeTimestamp) return new FakeTimestamp(new Date(value._date.getTime()));
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  if (isPlain(value)) {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = clone(v);
    return out;
  }
  return value;
};

const norm = (v) => {
  if (v instanceof FakeTimestamp) return v.toMillis();
  if (v instanceof Date) return v.getTime();
  if (v && typeof v.toMillis === 'function') return v.toMillis();
  return v;
};

const deepEqual = (a, b) => JSON.stringify(norm(a)) === JSON.stringify(norm(b));

const getPath = (obj, path) => {
  let node = obj;
  for (const key of path.split('.')) {
    if (node == null || typeof node !== 'object') return undefined;
    node = node[key];
  }
  return node;
};

function resolveValue(existing, value, clock) {
  if (!isSentinel(value)) return {set: true, value: clone(value)};
  switch (value.__op) {
    case 'serverTimestamp':
      return {set: true, value: new FakeTimestamp(clock())};
    case 'delete':
      return {set: false};
    case 'arrayUnion': {
      const base = Array.isArray(existing) ? [...existing] : [];
      for (const el of value.elements) if (!base.some((b) => deepEqual(b, el))) base.push(clone(el));
      return {set: true, value: base};
    }
    case 'arrayRemove': {
      const base = Array.isArray(existing) ? existing : [];
      return {set: true, value: base.filter((b) => !value.elements.some((el) => deepEqual(b, el)))};
    }
    case 'increment':
      return {set: true, value: (Number(existing) || 0) + value.n};
    default:
      throw new Error(`unknown sentinel ${value.__op}`);
  }
}

function mergeInto(target, data, clock) {
  for (const [key, value] of Object.entries(data)) {
    if (isPlain(value) && isPlain(target[key])) {
      mergeInto(target[key], value, clock);
    } else if (isPlain(value)) {
      target[key] = {};
      mergeInto(target[key], value, clock);
    } else {
      const r = resolveValue(target[key], value, clock);
      if (r.set) target[key] = r.value;
      else delete target[key];
    }
  }
}

function applyUpdate(existing, data, clock) {
  const out = clone(existing || {});
  for (const [path, value] of Object.entries(data)) {
    const keys = path.split('.');
    let node = out;
    for (const key of keys.slice(0, -1)) {
      if (!isPlain(node[key])) node[key] = {};
      node = node[key];
    }
    const last = keys[keys.length - 1];
    const r = resolveValue(node[last], value, clock);
    if (r.set) node[last] = r.value;
    else delete node[last];
  }
  return out;
}

function applySet(data, clock) {
  const out = {};
  mergeInto(out, data, clock);
  return out;
}

const matches = (docData, filter) => {
  const left = getPath(docData, filter.field);
  const right = filter.value;
  const nl = norm(left);
  const present = left !== undefined && left !== null;
  switch (filter.op) {
    case '==':
      return deepEqual(left, right);
    case '!=':
      return present && !deepEqual(left, right);
    case '<':
      return present && nl < norm(right);
    case '<=':
      return present && nl <= norm(right);
    case '>':
      return present && nl > norm(right);
    case '>=':
      return present && nl >= norm(right);
    case 'in':
      return present && right.some((r) => deepEqual(left, r));
    case 'not-in':
      return present && !right.some((r) => deepEqual(left, r));
    case 'array-contains':
      return Array.isArray(left) && left.some((l) => deepEqual(l, right));
    case 'array-contains-any':
      return Array.isArray(left) && left.some((l) => right.some((r) => deepEqual(l, r)));
    default:
      throw new Error(`unsupported operator ${filter.op}`);
  }
};

function createFakeFirestore(seed = {}, {now = () => new Date()} = {}) {
  const store = {};
  for (const [collection, docs] of Object.entries(seed)) {
    store[collection] = {};
    for (const [id, data] of Object.entries(docs)) store[collection][id] = clone(data);
  }
  const writes = [];
  let autoId = 0;

  const snapshotOf = (ref) => {
    const data = store[ref.collection] && store[ref.collection][ref.id];
    return {
      id: ref.id,
      ref,
      exists: data !== undefined,
      data: () => (data === undefined ? undefined : clone(data)),
    };
  };

  const commitWrite = (w) => {
    const {ref} = w;
    store[ref.collection] = store[ref.collection] || {};
    const existing = store[ref.collection][ref.id];
    if (w.op === 'set') {
      if (w.merge && existing) {
        const next = clone(existing);
        mergeInto(next, w.data, now);
        store[ref.collection][ref.id] = next;
      } else {
        store[ref.collection][ref.id] = applySet(w.data, now);
      }
    } else if (w.op === 'create') {
      if (existing) throw Object.assign(new Error(`ALREADY_EXISTS ${ref.path}`), {code: 6});
      store[ref.collection][ref.id] = applySet(w.data, now);
    } else if (w.op === 'update') {
      if (!existing) throw Object.assign(new Error(`NOT_FOUND ${ref.path}`), {code: 5});
      store[ref.collection][ref.id] = applyUpdate(existing, w.data, now);
    } else if (w.op === 'delete') {
      delete store[ref.collection][ref.id];
    }
    writes.push({op: w.op, path: ref.path});
  };

  const makeRef = (collection, id) => {
    const ref = {id, collection, path: `${collection}/${id}`};
    ref.get = async () => snapshotOf(ref);
    ref.set = async (data, options) => commitWrite({op: 'set', ref, data, merge: Boolean(options && options.merge)});
    ref.update = async (data) => commitWrite({op: 'update', ref, data});
    ref.create = async (data) => commitWrite({op: 'create', ref, data});
    ref.delete = async () => commitWrite({op: 'delete', ref});
    return ref;
  };

  const runQuery = (query) => {
    const docs = Object.entries(store[query.collection] || {})
      .filter(([, data]) => query.filters.every((f) => matches(data, f)))
      .map(([id]) => snapshotOf(makeRef(query.collection, id)));
    for (const o of [...query.orders].reverse()) {
      docs.sort((a, b) => {
        const av = norm(getPath(a.data(), o.field));
        const bv = norm(getPath(b.data(), o.field));
        if (av === bv) return 0;
        return (av < bv ? -1 : 1) * (o.dir === 'desc' ? -1 : 1);
      });
    }
    const limited = query.limitN != null ? docs.slice(0, query.limitN) : docs;
    return {
      docs: limited,
      size: limited.length,
      empty: limited.length === 0,
      forEach: (fn) => limited.forEach(fn),
    };
  };

  const makeQuery = (collection, filters = [], orders = [], limitN = null) => {
    const q = {collection, filters, orders, limitN, __isQuery: true};
    q.where = (field, op, value) => makeQuery(collection, [...filters, {field, op, value}], orders, limitN);
    q.orderBy = (field, dir = 'asc') => makeQuery(collection, filters, [...orders, {field, dir}], limitN);
    q.limit = (n) => makeQuery(collection, filters, orders, n);
    q.get = async () => runQuery(q);
    return q;
  };

  const db = {
    store,
    writes,
    FieldValue,
    Timestamp: FakeTimestamp,
    collection: (name) => {
      const query = makeQuery(name);
      query.doc = (id) => makeRef(name, id || `auto_${++autoId}`);
      query.add = async (data) => {
        const ref = makeRef(name, `auto_${++autoId}`);
        commitWrite({op: 'set', ref, data});
        return ref;
      };
      return query;
    },
    getAll: async (...refs) => refs.map(snapshotOf),
    batch: () => {
      const pending = [];
      const batch = {
        set: (ref, data, options) => pending.push({op: 'set', ref, data, merge: Boolean(options && options.merge)}),
        update: (ref, data) => pending.push({op: 'update', ref, data}),
        delete: (ref) => pending.push({op: 'delete', ref}),
        commit: async () => pending.forEach(commitWrite),
      };
      return batch;
    },
    runTransaction: async (fn) => {
      const buffered = [];
      let wrote = false;
      const guard = () => {
        if (wrote) throw new Error('Firestore transactions require all reads to be executed before all writes.');
      };
      const tx = {
        get: async (target) => {
          guard();
          return target.__isQuery ? runQuery(target) : snapshotOf(target);
        },
        getAll: async (...refs) => {
          guard();
          return refs.map(snapshotOf);
        },
        set: (ref, data, options) => {
          wrote = true;
          buffered.push({op: 'set', ref, data, merge: Boolean(options && options.merge)});
          return tx;
        },
        create: (ref, data) => {
          wrote = true;
          buffered.push({op: 'create', ref, data});
          return tx;
        },
        update: (ref, data) => {
          wrote = true;
          buffered.push({op: 'update', ref, data});
          return tx;
        },
        delete: (ref) => {
          wrote = true;
          buffered.push({op: 'delete', ref});
          return tx;
        },
      };
      const result = await fn(tx);
      buffered.forEach(commitWrite);
      return result;
    },
  };
  return db;
}

/** Wires the fake into the mocked firebase-admin used by tests/setup.js. */
function installOnAdmin(admin, db) {
  admin.firestore = jest.fn(() => db);
  admin.firestore.FieldValue = FieldValue;
  admin.firestore.Timestamp = FakeTimestamp;
  return admin;
}

module.exports = {createFakeFirestore, installOnAdmin, FakeTimestamp, FieldValue};
