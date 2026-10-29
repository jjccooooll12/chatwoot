<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { generateLabelForContactableInboxesList } from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper.js';

import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  targetInbox: {
    type: Object,
    default: null,
  },
  selectedContact: {
    type: Object,
    default: null,
  },
  showInboxesDropdown: {
    type: Boolean,
    required: true,
  },
  contactableInboxesList: {
    type: Array,
    default: () => [],
  },
  hasErrors: {
    type: Boolean,
    default: false,
  },
  isFetchingInboxes: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['toggleDropdown', 'handleInboxAction']);

const { t } = useI18n();

const targetInboxLabel = computed(() => {
  return generateLabelForContactableInboxesList(props.targetInbox);
});

const targetInboxEmailLabel = computed(() => `(${props.targetInbox?.email})`);
</script>

<template>
  <div
    class="flex items-center flex-1 w-full gap-3 px-4 py-3 overflow-y-visible"
  >
    <label class="mb-0.5 text-sm font-medium text-n-slate-11 whitespace-nowrap">
      {{ t('COMPOSE_NEW_CONVERSATION.FORM.INBOX_SELECTOR.LABEL') }}
    </label>
    <div
      v-if="targetInbox"
      class="flex min-w-0 items-center gap-1 text-[13px] leading-7"
    >
      <template v-if="targetInbox.email">
        <span class="truncate font-semibold text-fd-text">
          {{ targetInbox.name }}
        </span>
        <span class="truncate text-fd-muted">
          {{ targetInboxEmailLabel }}
        </span>
      </template>
      <span v-else class="truncate font-semibold text-fd-text">
        {{ targetInboxLabel }}
      </span>
    </div>
    <div
      v-else
      v-on-click-outside="() => emit('toggleDropdown', false)"
      class="relative flex items-center h-7"
    >
      <Spinner v-if="isFetchingInboxes" :size="16" />
      <Button
        v-else
        :label="t('COMPOSE_NEW_CONVERSATION.FORM.INBOX_SELECTOR.BUTTON')"
        variant="link"
        size="sm"
        :color="hasErrors ? 'ruby' : 'slate'"
        :disabled="!selectedContact"
        class="hover:!no-underline"
        @click="emit('toggleDropdown', !showInboxesDropdown)"
      />
      <DropdownMenu
        v-if="contactableInboxesList?.length > 0 && showInboxesDropdown"
        :menu-items="contactableInboxesList"
        class="ltr:left-0 rtl:right-0 z-[100] top-8 max-h-56 w-fit max-w-sm dark:!outline-n-slate-5"
        @action="emit('handleInboxAction', $event)"
      />
    </div>
  </div>
</template>
