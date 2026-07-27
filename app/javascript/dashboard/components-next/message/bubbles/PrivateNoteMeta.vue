<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import { dynamicTimeStrict, dateFormat } from 'shared/helpers/timeHelper';
import { shortenAgentName } from 'shared/helpers/agentNameHelper';

const { t } = useI18n();
const { sender, createdAt } = useMessageContext();

// A private note is always written by an agent, so the sender's last name is
// always abbreviated, matching every other agent name shown in the thread.
const displayName = computed(() => shortenAgentName(sender.value?.name || ''));

const timeZoneAbbr = computed(() => {
  if (!createdAt.value) return '';
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZoneName: 'short',
  }).formatToParts(new Date(createdAt.value * 1000));
  return parts.find(part => part.type === 'timeZoneName')?.value ?? '';
});

const timeText = computed(() => {
  if (!createdAt.value) return '';
  const stamp = dateFormat(createdAt.value, 'EEE, d MMM yyyy, h:mm a');
  const zone = timeZoneAbbr.value ? ` ${timeZoneAbbr.value}` : '';
  return `${dynamicTimeStrict(createdAt.value)} (${stamp}${zone})`;
});
</script>

<template>
  <div class="flex flex-wrap items-baseline gap-x-1.5 min-w-0 break-words">
    <span class="text-sm font-semibold text-fd-primary">
      {{ displayName }}
    </span>
    <span class="text-xs text-fd-muted">
      {{ t('CHAT_LIST.FRESHDESK_DETAIL.ADDED_PRIVATE_NOTE') }}
    </span>
    <template v-if="timeText">
      <span class="text-xs text-fd-muted">·</span>
      <span class="text-xs italic text-fd-muted">{{ timeText }}</span>
    </template>
  </div>
</template>
