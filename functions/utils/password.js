const DEFAULT_CHARSET = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';

const pickRandom = (value) => value[Math.floor(Math.random() * value.length)];

const shuffleString = (value) => value.split('').sort(() => Math.random() - 0.5).join('');

const generateRandomPassword = (length = 12) => {
  let password = '';

  password += pickRandom('ABCDEFGHIJKLMNOPQRSTUVWXYZ'); // uppercase
  password += pickRandom('abcdefghijklmnopqrstuvwxyz'); // lowercase
  password += pickRandom('0123456789'); // number
  password += pickRandom('!@#$%^&*'); // special char

  for (let i = 4; i < length; i += 1) {
    password += pickRandom(DEFAULT_CHARSET);
  }

  return shuffleString(password);
};

module.exports = {
  generateRandomPassword,
};

