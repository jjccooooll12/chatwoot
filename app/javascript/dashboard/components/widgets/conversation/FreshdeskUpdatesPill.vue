<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  count: { type: Number, required: true },
});

const emit = defineEmits(['refresh']);

const { t } = useI18n();
</script>

<!-- FRESHDESK-SKIN: floats over the top of the ticket list, like Freshdesk's
     "⟳ | 1 update" pill. The parent positions the wrapper. -->
<template>
  <button
    type="button"
    class="inline-flex h-9 items-center gap-2.5 rounded-full border border-fd-border bg-fd-surface ps-1.5 pe-4 text-[13px] text-fd-text shadow-md hover:bg-fd-blueSoft"
    @click="emit('refresh')"
  >
    <span
      class="flex size-6 items-center justify-center rounded-full bg-fd-action text-white"
    >
      <span class="i-lucide-refresh-cw size-3.5" />
    </span>
    <span class="h-4 w-px bg-fd-border" />
    <span>
      <strong class="font-semibold">{{ count }}</strong>
      {{ t('CHAT_LIST.FRESHDESK_UPDATES.LABEL', count) }}
    </span>
  </button>
</template>
