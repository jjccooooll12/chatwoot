/* eslint-disable no-console */
import NotificationSubscriptions from '../api/notificationSubscription';
import auth from '../api/auth';

export const verifyServiceWorkerExistence = (callback = () => {}) => {
  if (!('serviceWorker' in navigator)) {
    // Service Worker isn't supported on this browser, disable or hide UI.
    return;
  }

  if (!('PushManager' in window)) {
    // Push isn't supported on this browser, disable or hide UI.
    return;
  }

  navigator.serviceWorker
    .register('/sw.js')
    .then(registration => callback(registration))
    .catch(registrationError => {
      // eslint-disable-next-line
      console.log('SW registration failed: ', registrationError);
    });
};

export const hasPushPermissions = () => {
  if ('Notification' in window) {
    return Notification.permission === 'granted';
  }
  return false;
};

const generateKeys = str =>
  btoa(String.fromCharCode.apply(null, new Uint8Array(str)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

export const getPushSubscriptionPayload = subscription => ({
  subscription_type: 'browser_push',
  subscription_attributes: {
    endpoint: subscription.endpoint,
    p256dh: generateKeys(subscription.getKey('p256dh')),
    auth: generateKeys(subscription.getKey('auth')),
  },
});

export const sendRegistrationToServer = subscription => {
  if (auth.hasAuthCookie()) {
    return NotificationSubscriptions.create(
      getPushSubscriptionPayload(subscription)
    );
  }
  return null;
};

// FRESHDESK-SKIN: both steps used to swallow failures (a blocked site did
// nothing at all, a failed subscribe only logged), so a settings toggle looked
// on and silently came back off. They now report why, for the caller to show.
export const PUSH_FAILURE = {
  UNSUPPORTED: 'UNSUPPORTED',
  DENIED: 'DENIED',
  FAILED: 'FAILED',
};

const SERVICE_WORKER_TIMEOUT_MS = 10000;

// Per-device record that the person switched push off in Profile settings.
// The browser permission stays "granted" after that, so without it the
// auto-resubscribe on load (App.vue) would silently turn push back on.
const PUSH_OPT_OUT_KEY = 'fd_push_opted_out';

export const isPushOptedOut = () => {
  try {
    return localStorage.getItem(PUSH_OPT_OUT_KEY) === '1';
  } catch {
    return false;
  }
};

export const setPushOptedOut = optedOut => {
  try {
    if (optedOut) localStorage.setItem(PUSH_OPT_OUT_KEY, '1');
    else localStorage.removeItem(PUSH_OPT_OUT_KEY);
  } catch {
    // Storage blocked: the opt-out lasts only until the next load.
  }
};

const activeServiceWorker = async () => {
  await navigator.serviceWorker.register('/sw.js');
  return Promise.race([
    navigator.serviceWorker.ready,
    new Promise((_, reject) => {
      setTimeout(
        () => reject(new Error('Service worker did not start')),
        SERVICE_WORKER_TIMEOUT_MS
      );
    }),
  ]);
};

export const registerSubscription = async () => {
  const registration = await activeServiceWorker();
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: window.chatwootConfig.vapidPublicKey,
  });
  await sendRegistrationToServer(subscription);
};

// Older Safari only supports the callback form; newer browsers return a promise.
// Must be called synchronously from the tap that triggered it.
const askPermission = () =>
  new Promise(resolve => {
    const result = Notification.requestPermission(resolve);
    if (result) result.then(resolve);
  });

export const requestPushPermissions = async ({
  onSuccess = () => {},
  onFailure = () => {},
}) => {
  const supported =
    'Notification' in window &&
    'serviceWorker' in navigator &&
    'PushManager' in window &&
    window.chatwootConfig.vapidPublicKey;
  if (!supported) {
    onFailure(PUSH_FAILURE.UNSUPPORTED);
    return;
  }

  const permission =
    Notification.permission === 'default'
      ? await askPermission()
      : Notification.permission;
  if (permission !== 'granted') {
    onFailure(PUSH_FAILURE.DENIED);
    return;
  }

  try {
    await registerSubscription();
    setPushOptedOut(false);
    onSuccess();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Push subscription registration failed:', error);
    onFailure(PUSH_FAILURE.FAILED, error.message || String(error));
  }
};
