<script setup>
import { useI18n } from 'vue-i18n';
import { onKeyStroke } from '@vueuse/core';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

// FRESHDESK-SKIN: the phone-layout replacement for a desktop side column.
// Panels that sit beside the content on desktop (list filters, ticket
// properties, contact info) are rendered in this bottom sheet below `md:`.
// The parent mounts it with v-if; it is `md:hidden`, so a sheet left open
// while the window is widened simply disappears behind the desktop column.
defineProps({
  title: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['close']);
const { t } = useI18n();

onKeyStroke('Escape', () => emit('close'));
</script>

<template>
  <TeleportWithDirection to="body">
    <div class="fixed inset-0 z-50 flex flex-col justify-end md:hidden">
      <Transition
        appear
        enter-active-class="transition-opacity duration-200"
        enter-from-class="opacity-0"
      >
        <button
          type="button"
          tabindex="-1"
          :aria-label="t('CHAT_LIST.FRESHDESK_MOBILE.CLOSE')"
          class="absolute inset-0 bg-black/30"
          @click="emit('close')"
        />
      </Transition>
      <Transition
        appear
        enter-active-class="transition-transform duration-200 ease-out"
        enter-from-class="translate-y-full"
      >
        <section
          role="dialog"
          aria-modal="true"
          :aria-label="title"
          class="relative flex max-h-[85dvh] flex-col rounded-t-2xl bg-fd-surface pb-[env(safe-area-inset-bottom)] shadow-2xl"
        >
          <header
            class="flex shrink-0 items-center justify-between gap-3 border-b border-fd-border py-1 pl-4 pr-1"
          >
            <h2 class="m-0 truncate text-sm font-semibold text-fd-text">
              {{ title }}
            </h2>
            <button
              type="button"
              :aria-label="t('CHAT_LIST.FRESHDESK_MOBILE.CLOSE')"
              class="grid size-11 shrink-0 place-content-center rounded-lg text-fd-muted hover:bg-n-slate-3 hover:text-fd-text"
              @click="emit('close')"
            >
              <span class="i-lucide-x size-5" />
            </button>
          </header>
          <div class="min-h-0 flex-1 overflow-y-auto overscroll-contain">
            <slot />
          </div>
        </section>
      </Transition>
    </div>
  </TeleportWithDirection>
</template>
