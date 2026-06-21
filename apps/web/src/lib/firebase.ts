import { getApp, getApps, initializeApp, type FirebaseOptions } from "firebase/app";
import { browserLocalPersistence, getAuth, setPersistence } from "firebase/auth";
import { getFunctions } from "firebase/functions";
import { getFirestore, initializeFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

const devConfig: FirebaseOptions = {
  apiKey: "AIzaSyDS9nYN3GPN3p9adopyEC0oETjlmhEinGc",
  appId: "1:222814950724:web:734f42c0980c9c30f5b311",
  messagingSenderId: "222814950724",
  projectId: "alluwal-dev",
  authDomain: "alluwal-dev.firebaseapp.com",
  storageBucket: "alluwal-dev.firebasestorage.app",
  measurementId: "G-9T98VV4GPR",
};

const prodConfig: FirebaseOptions = {
  apiKey: "AIzaSyAi_iLhoVPezrUJTTu2az67Y1Pv31IsuP4",
  appId: "1:554077757249:web:07c7609546547fd6cc8bc0",
  messagingSenderId: "554077757249",
  projectId: "alluwal-academy",
  authDomain: "alluwal-academy.firebaseapp.com",
  storageBucket: "alluwal-academy.firebasestorage.app",
  measurementId: "G-F6605YZC8B",
};

const selectedConfig = process.env.NEXT_PUBLIC_FIREBASE_ENV === "prod" ? prodConfig : devConfig;

const firebaseConfig: FirebaseOptions = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || selectedConfig.apiKey,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || selectedConfig.appId,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || selectedConfig.messagingSenderId,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || selectedConfig.projectId,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || selectedConfig.authDomain,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || selectedConfig.storageBucket,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID || selectedConfig.measurementId,
};
export const hasFirebaseConfig = true;

export const firebaseApp = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);

let firestoreInstance: ReturnType<typeof getFirestore>;
try {
  firestoreInstance = initializeFirestore(firebaseApp, {
    experimentalAutoDetectLongPolling: true,
  });
} catch {
  firestoreInstance = getFirestore(firebaseApp);
}

export const db = firestoreInstance;

export const auth = getAuth(firebaseApp);
export const functions = getFunctions(firebaseApp, "us-central1");
export const storage = getStorage(firebaseApp);
export const firebaseProjectId = firebaseConfig.projectId;

let authPersistenceReady: Promise<void> | null = null;

export function ensureAuthPersistence() {
  const authInstance = requireAuth();
  authPersistenceReady ??= setPersistence(authInstance, browserLocalPersistence);
  return authPersistenceReady;
}

export function requireAuth() {
  return auth;
}
