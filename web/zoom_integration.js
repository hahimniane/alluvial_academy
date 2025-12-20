/**
 * Zoom Web SDK Integration for Flutter
 * This file provides JavaScript functions that Flutter can call via JS interop
 * to join Zoom meetings using the Zoom Meeting SDK for Web.
 */

(function () {
  'use strict';

  // Track SDK state
  var zoomState = {
    initialized: false,
    joining: false,
    inMeeting: false,
    error: null
  };

  // Callback functions set from Flutter
  var callbacks = {
    onStateChange: null,
    onError: null,
    onMeetingEnd: null
  };

  /**
   * Initialize the Zoom Web SDK
   * Must be called before joining a meeting
   */
  window.initZoomWebSDK = function () {
    return new Promise(function (resolve, reject) {
      try {
        if (typeof ZoomMtg === 'undefined') {
          reject('Zoom SDK not loaded');
          return;
        }

        console.log('Initializing Zoom Web SDK...');
        console.log('System Requirements:', JSON.stringify(ZoomMtg.checkSystemRequirements()));

        // Preload WebAssembly modules
        ZoomMtg.preLoadWasm();
        ZoomMtg.prepareWebSDK();

        zoomState.initialized = true;
        updateState('initialized');
        resolve(true);
      } catch (e) {
        console.error('Failed to initialize Zoom SDK:', e);
        zoomState.error = e.message || 'Initialization failed';
        updateState('error');
        reject(e.message || 'Initialization failed');
      }
    });
  };

  /**
   * Join a Zoom meeting
   * @param {Object} config - Meeting configuration
   * @param {string} config.meetingNumber - The meeting number
   * @param {string} config.userName - Display name for the user
   * @param {string} config.signature - JWT signature from backend
   * @param {string} config.passWord - Meeting password
   * @param {string} config.userEmail - User's email (optional)
   * @param {string} config.lang - Language code (default: 'en-US')
   * @param {string} config.sdkKey - Meeting SDK Client ID
   * @param {string} config.leaveUrl - URL to redirect to when leaving (optional)
   */
  window.joinZoomMeeting = function (config) {
    return new Promise(function (resolve, reject) {
      try {
        if (!zoomState.initialized) {
          reject('SDK not initialized. Call initZoomWebSDK first.');
          return;
        }

        if (zoomState.joining || zoomState.inMeeting) {
          reject('Already joining or in a meeting');
          return;
        }

        zoomState.joining = true;
        updateState('joining');

        var meetingConfig = {
          meetingNumber: config.meetingNumber,
          userName: config.userName,
          signature: config.signature,
          sdkKey: config.sdkKey,
          passWord: config.passWord || '',
          userEmail: config.userEmail || '',
          lang: config.lang || 'en-US',
          leaveUrl: config.leaveUrl || window.location.origin
        };

        console.log('Joining Zoom meeting:', meetingConfig.meetingNumber);

        // Load language pack
        ZoomMtg.i18n.load(meetingConfig.lang);
        ZoomMtg.i18n.onLoad(function () {
          // Initialize the Zoom client
          ZoomMtg.init({
            leaveUrl: meetingConfig.leaveUrl,
            disableCORP: !window.crossOriginIsolated,
            success: function () {
              console.log('Zoom SDK init success, joining meeting...');

              // Join the meeting
              ZoomMtg.join({
                meetingNumber: meetingConfig.meetingNumber,
                userName: meetingConfig.userName,
                signature: meetingConfig.signature,
                sdkKey: meetingConfig.sdkKey,
                passWord: meetingConfig.passWord,
                userEmail: meetingConfig.userEmail,
                success: function (res) {
                  console.log('Joined meeting successfully:', res);
                  zoomState.joining = false;
                  zoomState.inMeeting = true;
                  updateState('inMeeting');
                  resolve(true);
                },
                error: function (res) {
                  console.error('Failed to join meeting:', res);
                  zoomState.joining = false;
                  zoomState.error = res.errorMessage || 'Failed to join meeting';
                  updateState('error');
                  reject(zoomState.error);
                }
              });
            },
            error: function (res) {
              console.error('Zoom SDK init failed:', res);
              zoomState.joining = false;
              zoomState.error = res.errorMessage || 'SDK init failed';
              updateState('error');
              reject(zoomState.error);
            }
          });

          // Set up meeting event listeners
          setupMeetingListeners();
        });
      } catch (e) {
        console.error('Exception joining meeting:', e);
        zoomState.joining = false;
        zoomState.error = e.message || 'Join exception';
        updateState('error');
        reject(e.message || 'Join exception');
      }
    });
  };

  /**
   * Leave the current Zoom meeting
   */
  window.leaveZoomMeeting = function () {
    return new Promise(function (resolve, reject) {
      try {
        if (!zoomState.inMeeting) {
          resolve(true);
          return;
        }

        ZoomMtg.leaveMeeting({
          success: function () {
            console.log('Left meeting successfully');
            zoomState.inMeeting = false;
            updateState('ended');
            resolve(true);
          },
          error: function (res) {
            console.error('Failed to leave meeting:', res);
            reject(res.errorMessage || 'Failed to leave meeting');
          }
        });
      } catch (e) {
        console.error('Exception leaving meeting:', e);
        reject(e.message || 'Leave exception');
      }
    });
  };

  /**
   * Get the current Zoom SDK state
   */
  window.getZoomState = function () {
    return {
      initialized: zoomState.initialized,
      joining: zoomState.joining,
      inMeeting: zoomState.inMeeting,
      error: zoomState.error
    };
  };

  /**
   * Check if Zoom SDK is available
   */
  window.isZoomSDKAvailable = function () {
    return typeof ZoomMtg !== 'undefined';
  };

  /**
   * Set callback for state changes
   * @param {Function} callback - Function to call when state changes
   */
  window.setZoomStateCallback = function (callback) {
    callbacks.onStateChange = callback;
  };

  /**
   * Set callback for errors
   * @param {Function} callback - Function to call on error
   */
  window.setZoomErrorCallback = function (callback) {
    callbacks.onError = callback;
  };

  /**
   * Set callback for meeting end
   * @param {Function} callback - Function to call when meeting ends
   */
  window.setZoomMeetingEndCallback = function (callback) {
    callbacks.onMeetingEnd = callback;
  };

  /**
   * Show/hide the Zoom meeting UI
   * @param {boolean} show - Whether to show the meeting UI
   */
  window.showZoomMeetingUI = function (show) {
    var zoomContainer = document.getElementById('zmmtg-root');
    if (zoomContainer) {
      zoomContainer.style.display = show ? 'block' : 'none';
    }
  };

  /**
   * Update state and notify Flutter
   */
  function updateState(state) {
    console.log('Zoom state changed:', state);
    if (callbacks.onStateChange) {
      try {
        callbacks.onStateChange(state);
      } catch (e) {
        console.error('State callback error:', e);
      }
    }
  }

  /**
   * Set up meeting event listeners
   */
  function setupMeetingListeners() {
    ZoomMtg.inMeetingServiceListener('onUserJoin', function (data) {
      console.log('User joined:', data);
    });

    ZoomMtg.inMeetingServiceListener('onUserLeave', function (data) {
      console.log('User left:', data);
    });

    ZoomMtg.inMeetingServiceListener('onMeetingStatus', function (data) {
      console.log('Meeting status changed:', data);

      // Check for meeting end
      if (data && data.meetingStatus === 3) { // Meeting ended
        zoomState.inMeeting = false;
        updateState('ended');
        if (callbacks.onMeetingEnd) {
          try {
            callbacks.onMeetingEnd();
          } catch (e) {
            console.error('Meeting end callback error:', e);
          }
        }
      }
    });

    ZoomMtg.inMeetingServiceListener('onUserIsInWaitingRoom', function (data) {
      console.log('User in waiting room:', data);
    });
  }

  /**
   * Reset the SDK state (for re-initialization)
   */
  window.resetZoomSDK = function () {
    zoomState.initialized = false;
    zoomState.joining = false;
    zoomState.inMeeting = false;
    zoomState.error = null;
  };

  // Log when script loads
  console.log('Zoom integration script loaded');
})();
