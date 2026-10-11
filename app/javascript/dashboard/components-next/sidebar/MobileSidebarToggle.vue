<script setup>
import {
  useMobileSidebar,
  useRegisterHeaderToggle,
} from 'dashboard/composables/useMobileSidebar';

const { toggle } = useMobileSidebar();
useRegisterHeaderToggle();
</script>

<!-- FRESHDESK-SKIN: the phone nav button for page headers; replaces the
     floating launcher, which covered list rows and pagination. -->
<template>
  <button
    type="button"
    data-mobile-sidebar-toggle
    class="grid size-9 shrink-0 place-content-center rounded-md text-fd-text hover:bg-n-slate-3 md:hidden"
    :aria-label="$t('CHAT_LIST.FRESHDESK_MOBILE.MAIN_MENU')"
    @click="toggle"
  >
    <span class="i-lucide-menu size-5" />
  </button>
</template>
