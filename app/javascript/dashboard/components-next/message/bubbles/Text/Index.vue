<script setup>
import { computed, ref } from 'vue';
import { useWindowSize } from '@vueuse/core';
import BaseBubble from 'next/message/bubbles/Base.vue';
import Avatar from 'next/avatar/Avatar.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import PrivateNoteMeta from 'next/message/bubbles/PrivateNoteMeta.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';
import { useInbox } from 'dashboard/composables/useInbox';

const {
  content,
  attachments,
  contentAttributes,
  messageType,
  isPrivate,
  sender,
} = useMessageContext();
const { isAnEmailChannel } = useInbox();

// A private note on an email ticket gets its own Freshdesk-style header
// (sender + "added a private note" + time) and left-side avatar, matching
// the exact card layout regular email messages use (bubbles/Email/Index.vue)
// — only the background differs.
const isPrivateEmailNote = computed(
  () => isPrivate.value && isAnEmailChannel.value
);

const senderThumbnail = computed(() => sender.value?.thumbnail);
const { width: windowWidth } = useWindowSize();
const clampedAvatarSize = computed(() => {
  const width = windowWidth.value || 1440;
  return Math.min(24, Math.max(20, Math.round(width * 0.018)));
});

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);

const renderContent = computed(() => {
  if (renderOriginal.value) {
    return content.value;
  }

  if (hasTranslations.value) {
    return translationContent.value;
  }

  return content.value;
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};
</script>

<template>
  <BaseBubble
    :class="isPrivateEmailNote ? 'w-full' : 'px-4 py-3'"
    :hide-meta="isPrivateEmailNote"
    data-bubble-name="text"
  >
    <!-- Same card layout as a regular email message (bubbles/Email/Index.vue)
    — left avatar + header/content column — only the background differs. -->
    <div
      v-if="isPrivateEmailNote"
      class="flex w-full gap-3 px-3.5 pb-0.5 pt-3.5"
    >
      <Avatar
        :name="sender?.name"
        :src="senderThumbnail"
        :size="clampedAvatarSize"
        rounded-full
        class="shrink-0"
      />
      <div class="min-w-0 flex-1">
        <PrivateNoteMeta class="mb-2" />
        <div class="gap-3 flex flex-col">
          <span v-if="isEmpty" class="text-n-slate-11">
            {{ $t('CONVERSATION.NO_CONTENT') }}
          </span>
          <FormattedContent v-if="renderContent" :content="renderContent" />
          <TranslationToggle
            v-if="hasTranslations"
            class="-mt-3"
            :showing-original="renderOriginal"
            @toggle="handleSeeOriginal"
          />
          <AttachmentChips :attachments="attachments" class="gap-2" />
        </div>
      </div>
    </div>
    <div v-else class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <FormattedContent v-if="renderContent" :content="renderContent" />
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>
