/**
 * Jest Setup File for Firebase Cloud Functions Tests
 * This file is run before each test file
 */

// Mock firebase-admin before any tests run
jest.mock('firebase-admin', () => {
  const mockFirestore = {
    collection: jest.fn(() => mockFirestore),
    doc: jest.fn(() => mockFirestore),
    get: jest.fn(),
    set: jest.fn(),
    update: jest.fn(),
    batch: jest.fn(() => ({
      set: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      commit: jest.fn(() => Promise.resolve()),
    })),
    where: jest.fn(() => mockFirestore),
    orderBy: jest.fn(() => mockFirestore),
    limit: jest.fn(() => mockFirestore),
  };

  return {
    apps: [],
    initializeApp: jest.fn(),
    firestore: jest.fn(() => mockFirestore),
    auth: jest.fn(),
    credential: {
      applicationDefault: jest.fn(),
    },
  };
});

// Set test environment variables
process.env.GCLOUD_PROJECT = 'test-project';
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: 'test-project',
});

// Suppress console warnings during tests
const originalConsoleWarn = console.warn;
console.warn = (...args) => {
  if (args[0]?.includes?.('firebase') || args[0]?.includes?.('admin')) {
    return;
  }
  originalConsoleWarn.apply(console, args);
};

// Global test utilities
global.createMockTimestamp = (date) => ({
  toDate: () => date,
  seconds: Math.floor(date.getTime() / 1000),
  nanoseconds: 0,
});

// Clean up after all tests
afterAll(() => {
  jest.clearAllMocks();
});
