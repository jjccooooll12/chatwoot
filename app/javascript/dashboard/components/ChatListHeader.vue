<script setup>
import { computed } from 'vue';
import { formatNumber } from '@chatwoot/utils';
import { useMapGetter } from 'dashboard/composables/store';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import Avatar from 'next/avatar/Avatar.vue';

const props = defineProps({
  pageTitle: { type: String, required: true },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
]);

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));
const currentUser = useMapGetter('getCurrentUser');
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const notificationMetadata = useMapGetter('notifications/getMeta');
const unreadNotificationCount = computed(() => {
  const count = notificationMetadata.value?.unreadCount || 0;
  if (!count) return '';
  return count < 100 ? `${count}` : '99+';
});
</script>

<template>
  <!-- FRESHDESK-SKIN: header sits on the lavender chrome with a persistent divider -->
  <div
    class="flex items-center justify-between gap-3 px-3 h-[3.25rem] border-b border-fd-border bg-fd-surface"
  >
    <!-- FRESHDESK-SKIN: bolder title, always-on purple total-count badge, subtle status chip -->
    <div class="flex items-center min-w-0 gap-1.5">
      <h1
        class="text-base font-semibold truncate text-fd-text"
        :title="pageTitle"
      >
        {{ pageTitle }}
      </h1>
      <span
        v-if="allCount > 0 && !isListLoading"
        class="shrink-0 rounded-md bg-fd-primary px-2 py-0.5 text-xxs font-semibold text-white"
        :title="allCount"
      >
        {{ formattedAllCount }}
      </span>
      <span
        v-if="!hasAppliedFiltersOrActiveFolders"
        class="shrink-0 rounded-md border border-fd-border bg-fd-surface px-2 py-0.5 text-xxs capitalize text-fd-muted"
      >
        {{ $t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${activeStatus}.TEXT`) }}
      </span>
    </div>
    <div class="flex items-center gap-1.5">
      <template v-if="hasAppliedFilters && !hasActiveFolders">
        <div class="relative">
          <NextButton
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
            icon="i-lucide-save"
            slate
            xs
            faded
            @click="emit('addFolders')"
          />
          <div
            id="saveFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <NextButton
          v-tooltip.top-end="$t('FILTER.CLEAR_BUTTON_LABEL')"
          icon="i-lucide-circle-x"
          ruby
          faded
          xs
          @click="emit('resetFilters')"
        />
      </template>
      <template v-if="hasActiveFolders">
        <div class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
            icon="i-lucide-pen-line"
            slate
            xs
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
          icon="i-lucide-trash-2"
          ruby
          xs
          faded
          @click="emit('deleteFolders')"
        />
      </template>
      <div v-else class="relative">
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
          icon="i-lucide-list-filter"
          slate
          xs
          faded
          @click="emit('filtersModal')"
        />
        <div
          id="conversationFilterTeleportTarget"
          class="absolute z-50 mt-2"
          :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
        />
      </div>
      <ConversationBasicFilter
        v-if="!hasAppliedFiltersOrActiveFolders"
        :is-on-expanded-layout="isOnExpandedLayout"
        @change-filter="onBasicFilterChange"
      />
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
        class="grid size-8 place-content-center rounded-lg border border-fd-border bg-fd-surface text-fd-muted hover:border-fd-primary hover:text-fd-primary"
        :title="$t('COMBOBOX.SEARCH_PLACEHOLDER')"
      >
        <span class="i-lucide-search size-4" />
      </RouterLink>
      <RouterLink
        :to="{ name: 'notifications_index' }"
        class="relative grid size-8 place-content-center rounded-lg border border-fd-border bg-fd-surface text-fd-muted hover:border-fd-primary hover:text-fd-primary"
        :title="$t('CHAT_LIST.FRESHDESK_TOPBAR.NOTIFICATIONS')"
      >
        <span class="i-lucide-bell size-4" />
        <span
          v-if="unreadNotificationCount"
          class="absolute -right-1 -top-1 grid min-h-4 min-w-4 place-items-center rounded-full bg-fd-red px-1 text-[9px] font-semibold leading-none text-white"
        >
          {{ unreadNotificationCount }}
        </span>
      </RouterLink>
      <button
        type="button"
        class="hidden size-8 place-content-center rounded-lg border border-fd-border bg-fd-surface text-fd-muted hover:border-fd-primary hover:text-fd-primary md:grid"
        :title="$t('CHAT_LIST.FRESHDESK_TOPBAR.HELP')"
      >
        <span class="i-lucide-circle-help size-4" />
      </button>
      <button
        type="button"
        class="hidden h-8 items-center gap-1.5 rounded-lg border border-fd-border bg-fd-surface px-2 text-xs font-medium text-fd-text hover:border-fd-primary hover:text-fd-primary lg:inline-flex"
        :title="$t('CHAT_LIST.FRESHDESK_TOPBAR.APPS')"
      >
        <span class="i-lucide-grid-3x3 size-4" />
        {{ $t('CHAT_LIST.FRESHDESK_TOPBAR.APPS') }}
      </button>
      <Avatar
        :size="32"
        :name="currentUser.available_name"
        :src="currentUser.avatar_url"
        :status="currentUserAvailability"
        class="ml-0.5 hidden shrink-0 md:flex"
      />
    </div>
  </div>
</template>
