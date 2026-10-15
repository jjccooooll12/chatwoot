<script setup>
import { computed } from 'vue';
import { REPLY_EDITOR_MODES } from './constants';

const props = defineProps({
  mode: {
    type: String,
    default: REPLY_EDITOR_MODES.REPLY,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  isReplyRestricted: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['setMode']);

// When replies are restricted the editor is forced into a private note.
const activeMode = computed(() =>
  props.isReplyRestricted ? REPLY_EDITOR_MODES.NOTE : props.mode
);

// FRESHDESK-SKIN: Reply / Note as tabs, like Freshdesk's composer.
const tabs = computed(() => [
  {
    mode: REPLY_EDITOR_MODES.REPLY,
    label: 'CHAT_LIST.FRESHDESK_DETAIL.REPLY',
    icon: 'i-lucide-mail',
    disabled: props.disabled || props.isReplyRestricted,
  },
  {
    mode: REPLY_EDITOR_MODES.NOTE,
    label: 'CHAT_LIST.FRESHDESK_DETAIL.NOTE',
    icon: 'i-lucide-file-text',
    disabled: props.disabled,
  },
]);
</script>

<template>
  <div class="flex items-center gap-1.5">
    <button
      v-for="tab in tabs"
      :key="tab.mode"
      type="button"
      class="inline-flex h-8 items-center gap-1.5 rounded-md border px-2.5 text-[13px] font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-60"
      :class="
        activeMode === tab.mode
          ? 'border-fd-action/30 bg-fd-blueSoft text-fd-action'
          : 'border-transparent bg-n-slate-2 text-fd-muted hover:bg-n-slate-3 hover:text-fd-text'
      "
      :disabled="tab.disabled"
      @click="activeMode !== tab.mode && emit('setMode', tab.mode)"
    >
      <span class="size-4" :class="tab.icon" />
      {{ $t(tab.label) }}
    </button>
  </div>
</template>
