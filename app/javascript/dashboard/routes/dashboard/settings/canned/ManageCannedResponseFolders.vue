<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import Modal from '../../../../components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  onClose: { type: Function, default: () => {} },
});

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const show = ref(true);
const newFolderName = ref('');
const isCreating = ref(false);
const editingId = ref(null);
const editingName = ref('');
const deletingId = ref(null);
const deleteTarget = ref(null);
const showDeleteConfirm = ref(false);

const folders = computed(() => getters.getCannedResponseFolders.value);

onMounted(() => {
  store.dispatch('getCannedResponseFolders');
});

const addFolder = async () => {
  const name = newFolderName.value.trim();
  if (!name) return;
  isCreating.value = true;
  try {
    await store.dispatch('createCannedResponseFolder', { name });
    newFolderName.value = '';
  } catch (error) {
    useAlert(t('CANNED_MGMT.FOLDERS.CREATE_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

const startEditing = folder => {
  editingId.value = folder.id;
  editingName.value = folder.name;
};

const cancelEditing = () => {
  editingId.value = null;
  editingName.value = '';
};

const saveEditing = async folder => {
  const name = editingName.value.trim();
  if (!name || name === folder.name) {
    cancelEditing();
    return;
  }
  try {
    await store.dispatch('updateCannedResponseFolder', { id: folder.id, name });
    cancelEditing();
  } catch (error) {
    useAlert(t('CANNED_MGMT.FOLDERS.RENAME_ERROR'));
  }
};

const askDelete = folder => {
  deleteTarget.value = folder;
  showDeleteConfirm.value = true;
};

const closeDeleteConfirm = () => {
  showDeleteConfirm.value = false;
  deleteTarget.value = null;
};

const confirmDelete = async () => {
  const folder = deleteTarget.value;
  if (!folder) return;
  deletingId.value = folder.id;
  closeDeleteConfirm();
  try {
    await store.dispatch('deleteCannedResponseFolder', folder.id);
  } catch (error) {
    useAlert(t('CANNED_MGMT.FOLDERS.DELETE_ERROR'));
  } finally {
    deletingId.value = null;
  }
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('CANNED_MGMT.FOLDERS.MODAL_TITLE')"
        :header-content="t('CANNED_MGMT.FOLDERS.MODAL_DESC')"
      />

      <div class="flex items-center gap-2 w-full px-0 pb-4">
        <input
          v-model="newFolderName"
          type="text"
          class="!mb-0"
          :placeholder="t('CANNED_MGMT.FOLDERS.NEW_FOLDER_PLACEHOLDER')"
          @keydown.enter.prevent="addFolder"
        />
        <NextButton
          type="button"
          :label="t('CANNED_MGMT.FOLDERS.ADD_BUTTON')"
          :disabled="!newFolderName.trim() || isCreating"
          :is-loading="isCreating"
          @click="addFolder"
        />
      </div>

      <p v-if="!folders.length" class="text-n-slate-11 text-body-main">
        {{ t('CANNED_MGMT.FOLDERS.EMPTY') }}
      </p>

      <ul
        v-else
        class="m-0 flex list-none flex-col gap-1 p-0 max-h-[18rem] overflow-y-auto"
      >
        <li
          v-for="folder in folders"
          :key="folder.id"
          class="flex items-center gap-2 py-1.5 px-2 rounded-md hover:bg-n-slate-2"
        >
          <Icon
            icon="i-lucide-folder"
            class="size-4 shrink-0 text-n-slate-11"
          />
          <input
            v-if="editingId === folder.id"
            v-model="editingName"
            type="text"
            class="!mb-0 flex-1"
            @keydown.enter.prevent="saveEditing(folder)"
            @keydown.esc="cancelEditing"
            @blur="saveEditing(folder)"
          />
          <span v-else class="flex-1 text-n-slate-12 text-body-main truncate">
            {{ folder.name }}
          </span>
          <NextButton
            v-if="editingId !== folder.id"
            icon="i-lucide-pencil"
            slate
            sm
            faded
            @click="startEditing(folder)"
          />
          <NextButton
            icon="i-lucide-trash-2"
            slate
            sm
            faded
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            :is-loading="deletingId === folder.id"
            @click="askDelete(folder)"
          />
        </li>
      </ul>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2 mt-2">
        <NextButton
          :label="t('CANNED_MGMT.FOLDERS.DONE_BUTTON')"
          @click="onClose"
        />
      </div>
    </div>

    <woot-delete-modal
      v-model:show="showDeleteConfirm"
      :on-close="closeDeleteConfirm"
      :on-confirm="confirmDelete"
      :title="t('CANNED_MGMT.FOLDERS.DELETE_CONFIRM.TITLE')"
      :message="t('CANNED_MGMT.FOLDERS.DELETE_CONFIRM.MESSAGE')"
      :message-value="deleteTarget ? `${deleteTarget.name} ?` : ''"
      :confirm-text="`${t('CANNED_MGMT.FOLDERS.DELETE_CONFIRM.YES')} ${deleteTarget?.name}`"
      :reject-text="`${t('CANNED_MGMT.FOLDERS.DELETE_CONFIRM.NO')} ${deleteTarget?.name}`"
    />
  </Modal>
</template>
