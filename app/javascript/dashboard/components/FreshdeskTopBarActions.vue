<script setup>
import { useMapGetter } from 'dashboard/composables/store';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'next/avatar/Avatar.vue';

const currentUser = useMapGetter('getCurrentUser');
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
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
    <RouterLink
      :to="{ name: 'search' }"
      class="flex h-8 w-48 shrink-0 items-center gap-2 rounded-lg border border-fd-border bg-fd-surface px-3 text-sm text-fd-muted transition-colors hover:border-fd-primary hover:text-fd-primary sm:w-56 lg:w-72"
    >
      <span class="i-lucide-search size-4 shrink-0" />
      <span class="truncate">
        {{ $t('CHAT_LIST.FRESHDESK_TOPBAR.SEARCH_PLACEHOLDER') }}
      </span>
    </RouterLink>
    <Avatar
      :size="32"
      :name="currentUser.available_name"
      :src="currentUser.avatar_url"
      :status="currentUserAvailability"
      class="shrink-0"
    />
  </div>
</template>
