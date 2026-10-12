<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Banner from 'dashboard/components/ui/Banner.vue';
import { requestPushPermissions } from 'dashboard/helper/pushHelper.js';

// FRESHDESK-SKIN: push is on by default for every agent (NotificationSetting::
// DEFAULT_PUSH_FLAGS), but a browser only delivers it once the person allows
// notifications on that device - and phones only let a page ask from a tap.
// So ask once per device, and on an iPhone outside the home-screen app (where
// Safari has no web push at all) explain how to get there instead.
const DISMISSED_KEY = 'fd_push_banner_dismissed';

const { t } = useI18n();

const readDismissed = () => {
  try {
    return localStorage.getItem(DISMISSED_KEY) === '1';
  } catch {
    return false;
  }
};

const dismissed = ref(readDismissed());
const permission = ref(
  'Notification' in window ? Notification.permission : 'unsupported'
);

const pushSupported =
  'serviceWorker' in navigator &&
  'PushManager' in window &&
  'Notification' in window;
const isIosBrowserTab =
  /iPhone|iPad|iPod/.test(navigator.userAgent) && !window.navigator.standalone;

const mode = computed(() => {
  if (dismissed.value || !window.chatwootConfig.vapidPublicKey) return null;
  if (pushSupported) return permission.value === 'default' ? 'ask' : null;
  return isIosBrowserTab ? 'install' : null;
});

const dismiss = () => {
  dismissed.value = true;
  try {
    localStorage.setItem(DISMISSED_KEY, '1');
  } catch {
    // Private mode: the banner simply comes back next visit.
  }
};

const enable = () => {
  requestPushPermissions({ onSuccess: () => {} });
  // requestPermission resolves after the person answers the OS prompt;
  // either answer means there is nothing left to ask on this device.
  dismiss();
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Banner
    v-if="mode === 'ask'"
    color-scheme="primary"
    :banner-message="t('APP_GLOBAL.PUSH_PERMISSION.MESSAGE')"
    :action-button-label="t('APP_GLOBAL.PUSH_PERMISSION.ENABLE')"
    action-button-icon="i-lucide-bell"
    has-action-button
    has-close-button
    @primary-action="enable"
    @close="dismiss"
  />
  <Banner
    v-else-if="mode === 'install'"
    color-scheme="primary"
    :banner-message="t('APP_GLOBAL.PUSH_PERMISSION.INSTALL_HINT')"
    has-close-button
    @close="dismiss"
  />
</template>
