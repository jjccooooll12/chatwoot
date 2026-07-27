<script setup>
import { computed } from 'vue';
import { messageTimestamp } from 'shared/helpers/timeHelper';
import BaseBubble from './Base.vue';
import { useMessageContext } from '../provider.js';

const { content, createdAt, contentAttributes } = useMessageContext();

const readableTime = computed(() =>
  messageTimestamp(createdAt.value, 'LLL d, h:mm a')
);

const isMergeActivity = computed(
  () => contentAttributes.value?.activity?.type === 'conversation_merged'
);
</script>

<template>
  <BaseBubble
    v-tooltip.top="readableTime"
    class="flex min-w-0 items-center gap-2 px-3 py-1 !rounded-xl"
    :class="
      isMergeActivity
        ? '!bg-n-ruby-3 !text-n-ruby-12 [&_a]:font-semibold [&_a]:text-n-ruby-12 [&_a]:underline'
        : ''
    "
    data-bubble-name="activity"
  >
    <span v-dompurify-html="content" :title="content" />
  </BaseBubble>
</template>
