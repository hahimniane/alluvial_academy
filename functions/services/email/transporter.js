const nodemailer = require('nodemailer');

const createTransporter = () =>
  nodemailer.createTransport({
    host: 'smtp.hostinger.com',
    port: 465,
    secure: true,
    auth: {
      user: 'support@alluwaleducationhub.org',
      pass: 'Kilopatra2025.',
    },
  });

module.exports = {
  createTransporter,
};

