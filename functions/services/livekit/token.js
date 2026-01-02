/**
 * LiveKit Token Generation Service
 * 
 * Generates access tokens for LiveKit rooms using the official livekit-server-sdk.
 * Docs: https://docs.livekit.io/home/get-started/authentication/
 */

const { AccessToken } = require('livekit-server-sdk');
const { getLiveKitConfig } = require('./config');

/**
 * Role-based permission presets.
 * Note: When canPublish is true, participants can publish all sources.
 * canPublishSources is not needed unless restricting what can be published.
 */
const RolePermissions = {
  /**
   * Teacher permissions:
   * - Can publish any track (camera, microphone, screen share)
   * - Can publish data messages
   * - Can subscribe to other participants
   */
  teacher: {
    canPublish: true,
    canPublishData: true,
    canSubscribe: true,
  },

  /**
   * Student permissions:
   * - Can publish camera and microphone (screen share restricted via UI)
   * - Can publish data messages
   * - Can subscribe to other participants
   */
  student: {
    canPublish: true,
    canPublishData: true,
    canSubscribe: true,
  },

  /**
   * Admin permissions (same as teacher):
   * - Full permissions
   */
  admin: {
    canPublish: true,
    canPublishData: true,
    canSubscribe: true,
  },
};

/**
 * Generate a LiveKit access token using official SDK.
 * 
 * @param {string} roomName - The room to grant access to
 * @param {Object} options - Token generation options
 * @param {string} options.identity - Unique identity for the participant (required)
 * @param {string} [options.name] - Display name for the participant
 * @param {Object} [options.metadata] - Additional metadata (JSON-serializable)
 * @param {number} [options.ttlSeconds] - Token TTL in seconds (default: 600 = 10 minutes)
 * @param {Object} [options.videoGrant] - Video permissions
 * @returns {Promise<string>} JWT access token
 */
const generateAccessToken = async (roomName, options) => {
  const { apiKey, apiSecret } = getLiveKitConfig();

  if (!roomName || typeof roomName !== 'string') {
    throw new Error('Room name is required');
  }

  if (!options.identity || typeof options.identity !== 'string') {
    throw new Error('Identity is required');
  }

  const ttlSeconds = options.ttlSeconds || 600; // Default 10 minutes

  const metadata =
    options.metadata == null ? undefined : JSON.stringify(options.metadata);

  // Create access token with the official SDK
  const at = new AccessToken(apiKey, apiSecret, {
    identity: options.identity,
    name: options.name || options.identity,
    ttl: `${ttlSeconds}s`, // TTL as string like "600s"
    metadata,
  });

  // Build video grant as plain object
  const videoGrant = {
    roomJoin: true,
    room: roomName,
    canPublish: options.videoGrant?.canPublish !== false, // Default true
    canPublishData: options.videoGrant?.canPublishData !== false, // Default true
    canSubscribe: options.videoGrant?.canSubscribe !== false, // Default true
  };

  at.addGrant(videoGrant);

  // Generate and return the token
  const token = await at.toJwt();
  return token;
};

/**
 * Generate a token for a teacher joining a room.
 * 
 * @param {string} roomName - Room name
 * @param {string} identity - Teacher's unique identity (UID)
 * @param {string} [displayName] - Teacher's display name
 * @param {Object} [metadata] - Additional metadata
 * @param {number} [ttlSeconds] - Token TTL (default: 600)
 * @returns {Promise<string>} JWT access token
 */
const generateTeacherToken = async (roomName, identity, displayName, metadata = {}, ttlSeconds = 600) => {
  return generateAccessToken(roomName, {
    identity,
    name: displayName || identity,
    metadata: { ...metadata, role: 'teacher' },
    ttlSeconds,
    videoGrant: RolePermissions.teacher,
  });
};

/**
 * Generate a token for a student joining a room.
 * 
 * @param {string} roomName - Room name
 * @param {string} identity - Student's unique identity (UID)
 * @param {string} [displayName] - Student's display name
 * @param {Object} [metadata] - Additional metadata
 * @param {number} [ttlSeconds] - Token TTL (default: 600)
 * @returns {Promise<string>} JWT access token
 */
const generateStudentToken = async (roomName, identity, displayName, metadata = {}, ttlSeconds = 600) => {
  return generateAccessToken(roomName, {
    identity,
    name: displayName || identity,
    metadata: { ...metadata, role: 'student' },
    ttlSeconds,
    videoGrant: RolePermissions.student,
  });
};

/**
 * Generate a token for an admin joining a room.
 * 
 * @param {string} roomName - Room name
 * @param {string} identity - Admin's unique identity (UID)
 * @param {string} [displayName] - Admin's display name
 * @param {Object} [metadata] - Additional metadata
 * @param {number} [ttlSeconds] - Token TTL (default: 600)
 * @returns {Promise<string>} JWT access token
 */
const generateAdminToken = async (roomName, identity, displayName, metadata = {}, ttlSeconds = 600) => {
  return generateAccessToken(roomName, {
    identity,
    name: displayName || identity,
    metadata: { ...metadata, role: 'admin' },
    ttlSeconds,
    videoGrant: RolePermissions.admin,
  });
};

/**
 * Generate a token based on role.
 * 
 * @param {string} roomName - Room name
 * @param {'teacher' | 'student' | 'admin'} role - User role
 * @param {string} identity - User's unique identity (UID)
 * @param {string} [displayName] - User's display name
 * @param {Object} [metadata] - Additional metadata
 * @param {number} [ttlSeconds] - Token TTL (default: 600)
 * @returns {Promise<string>} JWT access token
 */
const generateTokenForRole = async (roomName, role, identity, displayName, metadata = {}, ttlSeconds = 600) => {
  switch (role) {
    case 'teacher':
      return generateTeacherToken(roomName, identity, displayName, metadata, ttlSeconds);
    case 'admin':
      return generateAdminToken(roomName, identity, displayName, metadata, ttlSeconds);
    case 'student':
    default:
      return generateStudentToken(roomName, identity, displayName, metadata, ttlSeconds);
  }
};

module.exports = {
  generateAccessToken,
  generateTeacherToken,
  generateStudentToken,
  generateAdminToken,
  generateTokenForRole,
  RolePermissions,
};
