<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const router = useRouter();
const searchQuery = ref('');

// Typing here never navigates — only Enter jumps to the search page, and it
// jumps straight to results (query pre-filled) instead of a blank screen.
const onSearchEnter = () => {
  const q = searchQuery.value.trim();
  if (!q) return;
  router.push({ name: 'search', query: { q } });
  searchQuery.value = '';
};
</script>

<template>
  <!-- Single source of truth for the top-right actions — used identically by
       ChatListHeader.vue (ticket list) and ConversationHeader.vue (ticket
       detail) so New/Search never move or change shape between pages. -->
  <div class="flex shrink-0 items-center gap-2">
    <ComposeConversation align="end">
      <template #trigger="{ isOpen }">
        <NextButton
          :label="$t('CHAT_LIST.FRESHDESK_TOPBAR.NEW')"
          icon="i-lucide-plus"
          sm
          class="!bg-fd-action !text-white hover:enabled:!brightness-110"
          :class="{ '!brightness-110': isOpen }"
        />
      </template>
    </ComposeConversation>
    <div
      class="flex h-8 w-48 shrink-0 items-center gap-2 rounded-lg border border-fd-border bg-fd-surface px-3 text-sm text-fd-muted transition-colors focus-within:border-fd-primary hover:border-fd-primary sm:w-56 lg:w-72"
    >
      <span class="i-lucide-search size-4 shrink-0" />
      <input
        v-model="searchQuery"
        type="text"
        :placeholder="$t('CHAT_LIST.FRESHDESK_TOPBAR.SEARCH_PLACEHOLDER')"
        class="reset-base w-full min-w-0 truncate border-none bg-transparent p-0 text-sm text-fd-text shadow-none outline-none placeholder:text-fd-muted focus:border-none focus:shadow-none focus:outline-none focus:ring-0"
        @keydown.enter="onSearchEnter"
      />
    </div>
  </div>
</template>
