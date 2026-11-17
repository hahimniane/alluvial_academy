/**
 * Password utility functions
 */

const crypto = require('crypto');

/**
 * Generate a random secure password
 * @returns {string} A random 12-character password
 */
function generateRandomPassword() {
  const lowercase = 'abcdefghijklmnopqrstuvwxyz';
  const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const numbers = '0123456789';
  const special = '!@#$%^&*';
  const allChars = lowercase + uppercase + numbers + special;
  const pick = (chars) => chars[crypto.randomInt(chars.length)];

  const chars = [pick(lowercase), pick(uppercase), pick(numbers), pick(special)];
  for (let i = 0; i < 8; i++) chars.push(pick(allChars));

  for (let i = chars.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}

// Short, common, friendly words a child can spell. No names, nothing that
// reads badly next to a number.
const EASY_WORDS = Object.freeze([
  'apple', 'arrow', 'bagel', 'baker', 'beach', 'berry', 'bird', 'boat', 'book', 'brave',
  'bread', 'brick', 'brook', 'brush', 'cake', 'camel', 'candy', 'canoe', 'card', 'cedar',
  'chair', 'chalk', 'cherry', 'chess', 'cloud', 'clover', 'coast', 'cocoa', 'comet', 'coral',
  'corn', 'crane', 'crayon', 'cream', 'daisy', 'desk', 'dolphin', 'dove', 'dragon', 'dream',
  'drum', 'duck', 'eagle', 'earth', 'falcon', 'farm', 'feather', 'fern', 'field', 'flag',
  'flower', 'flute', 'forest', 'fox', 'frog', 'fruit', 'garden', 'gecko', 'giraffe', 'glove',
  'goat', 'grape', 'grass', 'green', 'guitar', 'happy', 'harbor', 'hawk', 'hill', 'honey',
  'horse', 'house', 'island', 'jacket', 'jelly', 'jungle', 'kite', 'koala', 'ladder', 'lake',
  'lamp', 'lemon', 'leopard', 'light', 'lion', 'llama', 'lucky', 'mango', 'maple', 'marble',
  'meadow', 'melon', 'mint', 'mirror', 'monkey', 'moon', 'mountain', 'music', 'nest', 'ocean',
  'olive', 'orange', 'otter', 'owl', 'paint', 'panda', 'paper', 'parrot', 'peach', 'pearl',
  'pebble', 'pencil', 'penguin', 'pepper', 'piano', 'pillow', 'pine', 'planet', 'plum', 'pony',
  'pumpkin', 'puzzle', 'rabbit', 'rain', 'rainbow', 'river', 'robin', 'rocket', 'rose', 'ruby',
  'sail', 'salad', 'sand', 'seal', 'shell', 'ship', 'silver', 'sky', 'snow', 'sock',
  'spoon', 'spring', 'star', 'stone', 'storm', 'sugar', 'summer', 'sun', 'sunny', 'swan',
  'table', 'tiger', 'toast', 'tomato', 'tower', 'train', 'tree', 'tulip', 'turtle', 'valley',
  'violin', 'wagon', 'water', 'whale', 'window', 'winter', 'wolf', 'yellow', 'zebra', 'zipper',
]);

const _nameParts = (avoid) =>
  (Array.isArray(avoid) ? avoid : [avoid])
    .flatMap((value) => String(value || '').toLowerCase().normalize('NFKD').replace(/[̀-ͯ]/g, '')
      .split(/[^a-z0-9]+/))
    .filter((part) => part.length >= 3);

const _sharesName = (word, parts) => parts.some((part) => word.includes(part) || part.includes(word));

/**
 * An easy-to-type password: one common word and four digits, e.g. "tiger4827".
 * Uses the crypto RNG. Words that overlap any part of `avoid` (the person's
 * names, Student ID) are never picked, so a password is never derived from
 * who it belongs to.
 * @param {{avoid?: Array<string>|string}} [options]
 * @returns {string}
 */
function generateEasyPassword(options = {}) {
  const parts = _nameParts(options.avoid);
  const words = EASY_WORDS.filter((word) => !_sharesName(word, parts));
  const pool = words.length > 0 ? words : EASY_WORDS;
  const word = pool[crypto.randomInt(pool.length)];
  const digits = String(crypto.randomInt(1000, 10000));
  return `${word}${digits}`;
}

module.exports = {
  generateRandomPassword,
  generateEasyPassword,
  EASY_WORDS,
};
