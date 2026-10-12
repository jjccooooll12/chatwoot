<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
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
  <div
    v-if="mode"
    role="status"
    class="flex flex-wrap items-center justify-center gap-x-4 gap-y-2 bg-n-brand px-4 py-2 text-sm text-white"
  >
    <span class="flex min-w-0 flex-1 items-start gap-2 md:flex-none">
      <span class="i-lucide-bell mt-0.5 size-4 shrink-0" />
      {{
        mode === 'ask'
          ? t('APP_GLOBAL.PUSH_PERMISSION.MESSAGE')
          : t('APP_GLOBAL.PUSH_PERMISSION.INSTALL_HINT')
      }}
    </span>
    <span class="flex shrink-0 items-center gap-2">
      <button
        v-if="mode === 'ask'"
        type="button"
        class="h-9 rounded-lg bg-white px-3 font-medium text-n-brand hover:bg-white/90 md:h-7"
        @click="enable"
      >
        {{ t('APP_GLOBAL.PUSH_PERMISSION.ENABLE') }}
      </button>
      <button
        type="button"
        class="h-9 rounded-lg px-3 text-white/90 hover:bg-white/10 md:h-7"
        @click="dismiss"
      >
        {{ t('GENERAL_SETTINGS.DISMISS') }}
      </button>
    </span>
  </div>
</template>
