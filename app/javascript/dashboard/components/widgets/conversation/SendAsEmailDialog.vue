<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  chat: { type: Object, required: true },
});

const emit = defineEmits(['switched']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const email = ref('');
const isSaving = ref(false);

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const isValidEmail = computed(() => EMAIL_PATTERN.test(email.value.trim()));

const open = () => {
  email.value = props.chat?.meta?.sender?.email || '';
  dialogRef.value?.open();
};

const handleConfirm = async () => {
  if (!isValidEmail.value || isSaving.value) return;
  isSaving.value = true;
  try {
    await store.dispatch('switchConversationToEmail', {
      conversationId: props.chat.id,
      email: email.value.trim(),
    });
    dialogRef.value?.close();
    emit('switched');
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        t('CHAT_LIST.FRESHDESK_DETAIL.SEND_EMAIL.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="t('CHAT_LIST.FRESHDESK_DETAIL.SEND_EMAIL.TITLE')"
    :description="t('CHAT_LIST.FRESHDESK_DETAIL.SEND_EMAIL.DESCRIPTION')"
    :confirm-button-label="t('CHAT_LIST.FRESHDESK_DETAIL.SEND_EMAIL.CONFIRM')"
    :disable-confirm-button="!isValidEmail"
    :is-loading="isSaving"
    @confirm="handleConfirm"
  >
    <label class="grid gap-1.5 text-sm">
      <span class="font-medium text-fd-text">
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.SEND_EMAIL.EMAIL_LABEL') }}
      </span>
      <input
        v-model="email"
        type="email"
        :placeholder="
          t('CHAT_LIST.FRESHDESK_DETAIL.SEND_EMAIL.EMAIL_PLACEHOLDER')
        "
        class="h-9 rounded-md border border-fd-border bg-fd-surface px-3 text-sm text-fd-text outline-none focus:border-fd-primary"
      />
    </label>
  </Dialog>
</template>
