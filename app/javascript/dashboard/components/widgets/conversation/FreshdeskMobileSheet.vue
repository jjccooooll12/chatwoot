<script setup>
import { useI18n } from 'vue-i18n';
import { onKeyStroke } from '@vueuse/core';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

// FRESHDESK-SKIN: the phone/tablet replacement for a desktop side column.
// Panels that sit beside the content on desktop (list filters, ticket
// properties, contact info, canned responses) are rendered in this bottom
// sheet below the width where their column fits.
// The parent mounts it with v-if; it hides itself from `hiddenFrom` up (the
// breakpoint where the desktop column appears), so a sheet left open while
// the window is widened simply disappears behind that column.
const props = defineProps({
  title: {
    type: String,
    required: true,
  },
  hiddenFrom: {
    type: String,
    default: 'md',
    validator: value => ['md', 'lg', 'xl'].includes(value),
  },
});

const emit = defineEmits(['close']);

// Spelled out so Tailwind sees every class.
const HIDDEN_FROM_CLASS = { md: 'md:hidden', lg: 'lg:hidden', xl: 'xl:hidden' };
const { t } = useI18n();

onKeyStroke('Escape', () => emit('close'));
</script>

<template>
  <TeleportWithDirection to="body">
    <!-- A bottom sheet on phones; from md up (tablets) a side drawer. -->
    <div
      class="fixed inset-0 z-50 flex flex-col justify-end md:flex-row"
      :class="HIDDEN_FROM_CLASS[props.hiddenFrom]"
    >
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
        enter-from-class="translate-y-full md:translate-y-0 md:ltr:translate-x-full md:rtl:-translate-x-full"
      >
        <section
          role="dialog"
          aria-modal="true"
          :aria-label="title"
          class="relative flex max-h-[85dvh] flex-col rounded-t-2xl bg-fd-surface pb-[env(safe-area-inset-bottom)] shadow-2xl md:max-h-none md:w-96 md:rounded-none"
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
