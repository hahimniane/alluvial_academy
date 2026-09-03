/**
 * The house email shell: blue masthead, light content card, quiet footer.
 *
 * Every message the school sends should look like it came from the same place,
 * so new emails wrap their body in this rather than shipping their own markup.
 * The palette matches the welcome email (#0386FF) that families already know.
 */
const BRAND_BLUE = '#0386FF';

const brandedEmailHtml = ({heading, bodyHtml, footerNote}) => `
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      body { font-family: Arial, Helvetica, sans-serif; color: #0f172a; margin: 0; padding: 0; background-color: #eef2f7; }
      .container { max-width: 600px; margin: 0 auto; padding: 20px; }
      .header { background-color: ${BRAND_BLUE}; color: #ffffff; padding: 20px; text-align: center; }
      .header h1 { margin: 0; font-size: 20px; line-height: 1.3; }
      .content { padding: 24px 20px; background-color: #f9f9f9; line-height: 1.6; }
      .content p { margin: 0 0 14px; }
      .button { background-color: ${BRAND_BLUE}; color: #ffffff !important; padding: 12px 20px; border-radius: 8px; text-decoration: none; display: inline-block; font-weight: bold; }
      .fallback { font-size: 12px; color: #475569; word-break: break-all; }
      .footer { text-align: center; padding: 20px; color: #666666; font-size: 12px; }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <h1>${heading}</h1>
      </div>
      <div class="content">
        ${bodyHtml}
        <p>JazakAllah khair,<br/>Alluwal Education Hub Team</p>
      </div>
      <div class="footer">
        <p>${footerNote || 'This is an automated message. Please do not reply to this email.'}</p>
      </div>
    </div>
  </body>
  </html>
`;

module.exports = {brandedEmailHtml, BRAND_BLUE};
