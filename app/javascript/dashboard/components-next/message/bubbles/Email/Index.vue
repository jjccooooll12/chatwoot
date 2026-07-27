<script setup>
import { computed, useTemplateRef, ref, onMounted, watch } from 'vue';
import { useWindowSize } from '@vueuse/core';
import { Letter } from 'vue-letter';
import { sanitizeTextForRender } from '@chatwoot/utils';
import { allowedCssProperties } from 'lettersanitizer';

import Icon from 'next/icon/Icon.vue';
import Avatar from 'next/avatar/Avatar.vue';
import { EmailQuoteExtractor } from 'dashboard/helper/emailQuoteExtractor.js';
import FormattedContent from 'next/message/bubbles/Text/FormattedContent.vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import EmailMeta from './EmailMeta.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';

import { useMessageContext } from '../../provider.js';
import { MESSAGE_TYPES } from 'next/message/constants.js';
import { useTranslations } from 'dashboard/composables/useTranslations';

const {
  content,
  contentAttributes,
  attachments,
  messageType,
  sender,
  forceEmailExpanded,
} = useMessageContext();
const { width: windowWidth } = useWindowSize();

const displayName = computed(
  () => sender.value?.name || contentAttributes.value?.email?.from?.[0] || ''
);
const senderThumbnail = computed(() => sender.value?.thumbnail);
const clampedAvatarSize = computed(() => {
  const width = windowWidth.value || 1440;
  return Math.min(24, Math.max(20, Math.round(width * 0.018)));
});

const isExpandable = ref(false);
const isExpanded = ref(false);
const showQuotedMessage = ref(false);
const renderOriginal = ref(false);
const contentContainer = useTemplateRef('contentContainer');

onMounted(() => {
  isExpandable.value = contentContainer.value?.scrollHeight > 400;
  if (forceEmailExpanded?.value) {
    isExpanded.value = true;
  }
});

watch(
  () => forceEmailExpanded?.value,
  value => {
    if (value) {
      isExpanded.value = true;
    }
  }
);

const isOutgoing = computed(() => messageType.value === MESSAGE_TYPES.OUTGOING);

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const originalEmailText = computed(() => {
  const text =
    contentAttributes?.value?.email?.textContent?.full ?? content.value;
  return sanitizeTextForRender(text);
});

const originalEmailHtml = computed(
  () =>
    contentAttributes?.value?.email?.htmlContent?.full ||
    originalEmailText.value
);

const hasEmailContent = computed(() => {
  return (
    contentAttributes?.value?.email?.textContent?.full ||
    contentAttributes?.value?.email?.htmlContent?.full
  );
});

const messageContent = computed(() => {
  // If translations exist and we're showing translations (not original)
  if (hasTranslations.value && !renderOriginal.value) {
    return translationContent.value;
  }
  // Otherwise show original content
  return content.value;
});

const textToShow = computed(() => {
  // If translations exist and we're showing translations (not original)
  if (hasTranslations.value && !renderOriginal.value) {
    return translationContent.value;
  }
  // Otherwise show original text
  return originalEmailText.value;
});

const fullHTML = computed(() => {
  // If translations exist and we're showing translations (not original)
  if (hasTranslations.value && !renderOriginal.value) {
    return translationContent.value;
  }
  // Otherwise show original HTML
  return originalEmailHtml.value;
});

const unquotedHTML = computed(() =>
  EmailQuoteExtractor.extractQuotes(fullHTML.value)
);

const hasQuotedMessage = computed(() =>
  EmailQuoteExtractor.hasQuotes(fullHTML.value)
);

// Ensure unique keys for <Letter> when toggling between original and translated views.
// This forces Vue to re-render the component and update content correctly.
const translationKeySuffix = computed(() => {
  if (renderOriginal.value) return 'original';
  if (hasTranslations.value) return 'translated';
  return 'original';
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};
</script>

<template>
  <BaseBubble class="w-full" hide-meta data-bubble-name="email">
    <div class="flex w-full gap-3 pb-1">
      <Avatar
        :name="displayName"
        :src="senderThumbnail"
        :size="clampedAvatarSize"
        rounded-full
        class="shrink-0"
      />
      <div
        class="min-w-0 flex-1 text-fd-text"
        :class="isOutgoing ? 'rounded-lg bg-n-slate-2 px-3.5 py-3' : 'pb-0.5'"
      >
        <EmailMeta class="mb-2" />
        <section ref="contentContainer">
          <div
            :class="{
              'max-h-[400px] overflow-hidden relative':
                !isExpanded && isExpandable,
              'overflow-y-scroll relative': isExpanded,
            }"
          >
            <div
              v-if="isExpandable && !isExpanded"
              class="absolute bottom-0 left-0 right-0 flex h-40 items-end bg-gradient-to-t from-fd-surface via-fd-surface via-20% to-transparent px-8"
            >
              <button
                class="text-n-slate-12 py-2 px-8 mx-auto text-center flex items-center gap-2"
                @click="isExpanded = true"
              >
                <Icon icon="i-lucide-maximize-2" />
                {{ $t('EMAIL_HEADER.EXPAND') }}
              </button>
            </div>
            <FormattedContent
              v-if="isOutgoing && content && !hasEmailContent"
              class="text-n-slate-12"
              :content="messageContent"
            />
            <template v-else>
              <Letter
                v-if="showQuotedMessage"
                :key="`letter-quoted-${translationKeySuffix}`"
                class-name="prose prose-bubble !max-w-none letter-render"
                :allowed-css-properties="[
                  ...allowedCssProperties,
                  'transform',
                  'transform-origin',
                ]"
                :html="fullHTML"
                :text="textToShow"
              />
              <Letter
                v-else
                :key="`letter-unquoted-${translationKeySuffix}`"
                class-name="prose prose-bubble !max-w-none letter-render"
                :html="unquotedHTML"
                :allowed-css-properties="[
                  ...allowedCssProperties,
                  'transform',
                  'transform-origin',
                ]"
                :text="textToShow"
              />
            </template>
            <button
              v-if="hasQuotedMessage"
              class="mt-2 flex items-center gap-1 text-xs leading-none text-fd-muted hover:text-fd-text"
              @click="showQuotedMessage = !showQuotedMessage"
            >
              <template v-if="showQuotedMessage">
                {{ $t('CHAT_LIST.HIDE_QUOTED_TEXT') }}
              </template>
              <template v-else>
                {{ $t('CHAT_LIST.SHOW_QUOTED_TEXT') }}
              </template>
              <Icon
                :icon="
                  showQuotedMessage
                    ? 'i-lucide-chevron-up'
                    : 'i-lucide-chevron-down'
                "
              />
            </button>
          </div>
        </section>
        <TranslationToggle
          v-if="hasTranslations"
          class="py-2 px-3"
          :showing-original="renderOriginal"
          @toggle="handleSeeOriginal"
        />
        <section
          v-if="Array.isArray(attachments) && attachments.length"
          class="mt-2 space-y-2"
        >
          <AttachmentChips :attachments="attachments" class="gap-1" />
        </section>
      </div>
    </div>
  </BaseBubble>
</template>

<style lang="scss">
// Tailwind resets break the rendering of google drive link in Gmail messages
// This fixes it using https://developer.mozilla.org/en-US/docs/Web/CSS/Attribute_selectors

.letter-render [class*='gmail_drive_chip'] {
  box-sizing: initial;
  @apply bg-n-slate-4 border-n-slate-6 rounded-md !important;

  a {
    @apply text-n-slate-12 !important;

    img {
      display: inline-block;
    }
  }
}

// Email clients (Gmail, Outlook) hardcode dir="ltr" on wrapper elements.
// In RTL apps this forces email content LTR regardless of actual text.
[dir='rtl'] .letter-render [dir='ltr'] {
  direction: inherit;
}
</style>
