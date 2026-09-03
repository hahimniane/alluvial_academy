jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: (_path, fn) => fn,
  onDocumentWritten: (_path, fn) => fn,
}));

const {_buildPricingHtml, _buildPaymentPolicyHtml} = require('../handlers/enrollments');

const enrollment = {
  pricing: {hourlyRate: 8.5, monthlyEstimate: 34, hoursPerWeek: 1},
};

describe('who is shown a price', () => {
  test('the family block names no figure', () => {
    const html = _buildPaymentPolicyHtml();
    expect(html).not.toMatch(/\$/);
    expect(html).not.toMatch(/Pricing Estimate/);
    expect(html).not.toMatch(/Hourly rate|Est\. monthly|Hours per week/);
  });

  test('the family block still says when payment is due', () => {
    expect(_buildPaymentPolicyHtml()).toMatch(/beginning of each month/);
  });

  test('the admin block still carries the estimate', () => {
    const html = _buildPricingHtml(enrollment);
    expect(html).toMatch(/Pricing Estimate/);
    expect(html).toMatch(/\$8\.50 USD/);
    expect(html).toMatch(/~\$34 USD/);
  });

  test('an enrollment with no pricing produces no admin block', () => {
    expect(_buildPricingHtml({})).toBe('');
  });
});
