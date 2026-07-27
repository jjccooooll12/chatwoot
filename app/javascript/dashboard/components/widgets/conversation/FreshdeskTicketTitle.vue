<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useWindowSize } from '@vueuse/core';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const { width: windowWidth } = useWindowSize();

const senderName = computed(() => {
  const sender = props.chat.meta?.sender || {};
  return (
    sender.name || sender.email || t('CHAT_LIST.FRESHDESK_CARD.UNASSIGNED')
  );
});

const accountName = computed(() =>
  t('CHAT_LIST.FRESHDESK_DETAIL.PEACH_LABELS')
);

const title = computed(() =>
  t('CHAT_LIST.FRESHDESK_DETAIL.CONTACT_FORM_TITLE', {
    customer: senderName.value,
    account: accountName.value,
  })
);

const clampedIconSize = computed(() => {
  const width = windowWidth.value || 1440;
  return Math.min(24, Math.max(20, Math.round(width * 0.018)));
});

const iconStyle = computed(() => ({
  width: `${clampedIconSize.value}px`,
  height: `${clampedIconSize.value}px`,
}));
</script>

<template>
  <section
    class="flex min-h-[clamp(4rem,6vw,4.75rem)] items-start justify-between gap-3 bg-fd-surface px-[clamp(0.75rem,1.4vw,1.25rem)] pb-7 pt-5"
  >
    <div class="flex min-w-0 items-center gap-3">
      <span
        class="grid shrink-0 place-content-center rounded-full bg-[#536273] text-white"
        :style="iconStyle"
      >
        <span
          class="i-lucide-align-justify size-[clamp(0.75rem,1vw,0.875rem)]"
        />
      </span>
      <h1
        class="m-0 min-w-0 truncate text-[clamp(0.8125rem,1vw,0.875rem)] font-semibold leading-5 text-fd-text"
      >
        {{ title }}
      </h1>
    </div>
    <button
      type="button"
      class="hidden h-7 items-center gap-1.5 rounded-md border border-[#cfe3ff] bg-[#f7fbff] px-2.5 text-xs font-semibold text-fd-primary shadow-sm hover:bg-fd-blueSoft md:inline-flex"
    >
      <span class="i-lucide-sparkles size-3.5" />
      {{ t('CHAT_LIST.FRESHDESK_DETAIL.SUMMARY') }}
    </button>
  </section>
</template>
