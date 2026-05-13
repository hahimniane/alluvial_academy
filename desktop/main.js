const { app, BrowserWindow, shell, session, Menu } = require('electron');
const path = require('path');

const APP_URL = 'https://www.alluwaleducationhub.org';

const ALLOWED_HOSTS = new Set([
  'alluwaleducationhub.org',
  'www.alluwaleducationhub.org',
]);

// Permissions the in-app site is allowed to use (LiveKit video calls need media + display-capture).
const ALLOWED_PERMISSIONS = new Set([
  'media',
  'mediaKeySystem',
  'geolocation',
  'notifications',
  'fullscreen',
  'clipboard-read',
  'clipboard-sanitized-write',
  'display-capture',
  'pointerLock',
]);

let mainWindow;

function hostOf(url) {
  try {
    return new URL(url).hostname;
  } catch (_) {
    return '';
  }
}

function isAppHost(url) {
  return ALLOWED_HOSTS.has(hostOf(url));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1024,
    minHeight: 640,
    backgroundColor: '#ffffff',
    title: 'Alluwal Education Hub',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: true,
    },
  });

  // Hide the default menubar but keep standard shortcuts (copy/paste/zoom/devtools).
  Menu.setApplicationMenu(null);

  session.defaultSession.setPermissionRequestHandler((webContents, permission, callback) => {
    if (isAppHost(webContents.getURL()) && ALLOWED_PERMISSIONS.has(permission)) {
      callback(true);
      return;
    }
    callback(false);
  });

  // window.open() and target="_blank" — keep app links in-window, send everything else to the system browser.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (isAppHost(url)) {
      return { action: 'allow' };
    }
    shell.openExternal(url);
    return { action: 'deny' };
  });

  // Direct navigation — same policy.
  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (!isAppHost(url)) {
      event.preventDefault();
      shell.openExternal(url);
    }
  });

  mainWindow.loadURL(APP_URL);
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
