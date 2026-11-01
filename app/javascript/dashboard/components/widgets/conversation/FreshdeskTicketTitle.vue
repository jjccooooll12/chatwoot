<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useWindowSize } from '@vueuse/core';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import { INBOX_TYPES, TWILIO_CHANNEL_MEDIUM } from 'dashboard/helper/inbox';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const store = useStore();
const { getPlainText } = useMessageFormatter();
const { width: windowWidth } = useWindowSize();

const lastMessageInChat = computed(() => getLastMessage(props.chat));
const inbox = computed(() =>
  store.getters['inboxes/getInbox'](props.chat.inbox_id || props.chat.inboxId)
);
const isWhatsApp = computed(() => {
  const channelType = inbox.value?.channel_type || inbox.value?.channelType;
  return (
    channelType === INBOX_TYPES.WHATSAPP ||
    (channelType === INBOX_TYPES.TWILIO &&
      inbox.value?.medium === TWILIO_CHANNEL_MEDIUM.WHATSAPP)
  );
});

// Same precedence as ConversationCard.vue's subject computed — the locked-in
// ticket subject, falling back to the last message so it's never blank.
const title = computed(() => {
  const additionalAttributes =
    props.chat.additional_attributes || props.chat.additionalAttributes || {};
  const emailSubject =
    additionalAttributes.mail_subject || additionalAttributes.mailSubject;
  return getPlainText(
    emailSubject ||
      lastMessageInChat.value?.content ||
      t('CHAT_LIST.NO_CONTENT')
  );
});

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
    class="flex min-h-[clamp(4rem,6vw,4.75rem)] items-start gap-3 bg-fd-surface px-[clamp(0.75rem,1.4vw,1.25rem)] pb-7 pt-5"
  >
    <div class="flex min-w-0 items-center gap-3">
      <span
        v-if="isWhatsApp"
        class="grid shrink-0 place-content-center"
        :style="iconStyle"
        aria-hidden="true"
      >
        <span class="i-logos-whatsapp-icon size-full" />
      </span>
      <span
        v-else
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
  </section>
</template>
