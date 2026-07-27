<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { MESSAGE_STATUS, MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { dynamicTimeStrict, dateFormat } from 'shared/helpers/timeHelper';
import { shortenAgentName } from 'shared/helpers/agentNameHelper';

const { t } = useI18n();
const { contentAttributes, status, sender, createdAt, messageType } =
  useMessageContext();

const hasError = computed(() => status.value === MESSAGE_STATUS.FAILED);

const fromEmail = computed(() => contentAttributes.value?.email?.from ?? []);

const toEmail = computed(() => {
  const { toEmails, email } = contentAttributes.value;
  return email?.to ?? toEmails ?? [];
});

const ccEmail = computed(
  () =>
    contentAttributes.value?.ccEmails ??
    contentAttributes.value?.email?.cc ??
    []
);

const bccEmail = computed(
  () =>
    contentAttributes.value?.bccEmails ??
    contentAttributes.value?.email?.bcc ??
    []
);

const isOutgoing = computed(() => messageType.value === MESSAGE_TYPES.OUTGOING);

// Agents are shown as "First L." (e.g. "Jason C.") rather than their full name,
// to keep the thread compact and consistent regardless of how long an agent's
// full name is. Customer names are always shown in full.
const displayName = computed(() => {
  const name = sender.value?.name || fromEmail.value[0] || '';
  return isOutgoing.value ? shortenAgentName(name) : name;
});
const viaText = computed(() =>
  isOutgoing.value
    ? t('CHAT_LIST.FRESHDESK_DETAIL.REPLIED_VIA_EMAIL')
    : t('CHAT_LIST.FRESHDESK_DETAIL.REPORTED_VIA_EMAIL')
);

// The browser renders times in the viewer's local timezone; surface which one
// (computed per message so DST — CET vs CEST etc. — is correct).
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

const showMeta = computed(
  () =>
    fromEmail.value[0] ||
    toEmail.value.length ||
    ccEmail.value.length ||
    bccEmail.value.length
);
</script>

<template>
  <section v-show="showMeta" class="min-w-0 space-y-0.5 break-words">
    <div class="flex flex-wrap items-baseline gap-x-1.5">
      <span
        class="text-sm font-semibold"
        :class="
          hasError
            ? 'text-n-ruby-11'
            : isOutgoing
              ? 'text-fd-primary'
              : 'text-fd-text'
        "
      >
        {{ displayName }}
      </span>
      <span class="text-xs text-fd-muted">{{ viaText }}</span>
      <template v-if="timeText">
        <span class="text-xs text-fd-muted">·</span>
        <span class="text-xs italic text-fd-muted">{{ timeText }}</span>
      </template>
    </div>
    <div v-if="toEmail.length" class="text-xs text-fd-text">
      <span class="font-semibold">{{ $t('EMAIL_HEADER.TO') }}:</span>
      {{ toEmail.join(', ') }}
    </div>
    <div v-if="ccEmail.length" class="text-xs text-fd-muted">
      {{ $t('EMAIL_HEADER.CC') }}: {{ ccEmail.join(', ') }}
    </div>
    <div v-if="bccEmail.length" class="text-xs text-fd-muted">
      {{ $t('EMAIL_HEADER.BCC') }}: {{ bccEmail.join(', ') }}
    </div>
  </section>
</template>
