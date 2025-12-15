const crypto = require('crypto');

const base64UrlEncode = (input) =>
  Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');

const base64UrlDecodeToBuffer = (input) => {
  const normalized = String(input).replace(/-/g, '+').replace(/_/g, '/');
  const pad = normalized.length % 4 === 0 ? '' : '='.repeat(4 - (normalized.length % 4));
  return Buffer.from(normalized + pad, 'base64');
};

const timingSafeEqual = (a, b) => {
  const bufA = Buffer.isBuffer(a) ? a : Buffer.from(a);
  const bufB = Buffer.isBuffer(b) ? b : Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
};

const signJoinToken = (payload, secret) => {
  const issuedAtSeconds = Math.floor(Date.now() / 1000);
  const safePayload = {
    ...payload,
    iat: payload.iat ?? issuedAtSeconds,
  };
  const body = base64UrlEncode(JSON.stringify(safePayload));
  const sig = base64UrlEncode(crypto.createHmac('sha256', secret).update(body).digest());
  return `${body}.${sig}`;
};

const verifyJoinToken = (token, secret) => {
  const [body, sig] = String(token).split('.');
  if (!body || !sig) {
    throw new Error('Invalid token format');
  }
  const expectedSig = base64UrlEncode(crypto.createHmac('sha256', secret).update(body).digest());
  if (!timingSafeEqual(sig, expectedSig)) {
    throw new Error('Invalid token signature');
  }
  const payload = JSON.parse(base64UrlDecodeToBuffer(body).toString('utf8'));

  const nowSeconds = Math.floor(Date.now() / 1000);
  if (payload.exp != null && Number(payload.exp) < nowSeconds) {
    throw new Error('Token expired');
  }

  return payload;
};

const getAes256GcmKey = (encryptionKeyB64) => {
  const key = Buffer.from(String(encryptionKeyB64), 'base64');
  if (key.length !== 32) {
    throw new Error('ZOOM_ENCRYPTION_KEY_B64 must be base64 for 32 bytes (AES-256-GCM).');
  }
  return key;
};

const encryptString = (plaintext, encryptionKeyB64) => {
  const key = getAes256GcmKey(encryptionKeyB64);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(String(plaintext), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${base64UrlEncode(iv)}.${base64UrlEncode(ciphertext)}.${base64UrlEncode(tag)}`;
};

const decryptString = (encrypted, encryptionKeyB64) => {
  const key = getAes256GcmKey(encryptionKeyB64);
  const [ivB64, ciphertextB64, tagB64] = String(encrypted).split('.');
  if (!ivB64 || !ciphertextB64 || !tagB64) {
    throw new Error('Invalid encrypted payload format');
  }
  const iv = base64UrlDecodeToBuffer(ivB64);
  const ciphertext = base64UrlDecodeToBuffer(ciphertextB64);
  const tag = base64UrlDecodeToBuffer(tagB64);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  return plaintext.toString('utf8');
};

module.exports = {
  signJoinToken,
  verifyJoinToken,
  encryptString,
  decryptString,
};

