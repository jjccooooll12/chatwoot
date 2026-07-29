<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

defineProps({
  modelValue: {
    type: [Number, String],
    default: '',
  },
});

const emit = defineEmits(['update:modelValue']);

const NEW_FOLDER_VALUE = '__new__';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const isAddingNew = ref(false);
const newFolderName = ref('');
const isCreating = ref(false);

const folders = computed(() => getters.getCannedResponseFolders.value);

onMounted(() => {
  store.dispatch('getCannedResponseFolders');
});

const onSelectChange = event => {
  const { value } = event.target;
  if (value === NEW_FOLDER_VALUE) {
    isAddingNew.value = true;
    return;
  }
  emit('update:modelValue', value);
};

const cancelNewFolder = () => {
  isAddingNew.value = false;
  newFolderName.value = '';
};

const createFolder = async () => {
  const name = newFolderName.value.trim();
  if (!name) return;
  isCreating.value = true;
  try {
    const folder = await store.dispatch('createCannedResponseFolder', {
      name,
    });
    isCreating.value = false;
    isAddingNew.value = false;
    newFolderName.value = '';
    emit('update:modelValue', folder.id);
  } catch (error) {
    isCreating.value = false;
    useAlert(t('CANNED_MGMT.FOLDERS.CREATE_ERROR'));
  }
};
</script>

<template>
  <div class="w-full">
    <label class="mb-1">
      {{ t('CANNED_MGMT.ADD.FORM.FOLDER.LABEL') }}
    </label>
    <select v-if="!isAddingNew" :value="modelValue" @change="onSelectChange">
      <option value="">{{ t('CANNED_MGMT.ADD.FORM.FOLDER.NONE') }}</option>
      <option v-for="folder in folders" :key="folder.id" :value="folder.id">
        {{ folder.name }}
      </option>
      <option :value="NEW_FOLDER_VALUE">
        {{ t('CANNED_MGMT.ADD.FORM.FOLDER.NEW_OPTION') }}
      </option>
    </select>
    <div v-else class="flex items-center gap-2">
      <input
        v-model="newFolderName"
        type="text"
        class="!mb-0 !w-auto flex-1 min-w-0"
        :placeholder="t('CANNED_MGMT.ADD.FORM.FOLDER.NEW_PLACEHOLDER')"
        @keydown.enter.prevent="createFolder"
      />
      <NextButton
        type="button"
        sm
        class="shrink-0 whitespace-nowrap"
        :label="t('CANNED_MGMT.FOLDERS.ADD_BUTTON')"
        :disabled="!newFolderName.trim() || isCreating"
        :is-loading="isCreating"
        @click="createFolder"
      />
      <NextButton
        type="button"
        sm
        faded
        slate
        class="shrink-0"
        icon="i-lucide-x"
        @click="cancelNewFolder"
      />
    </div>
  </div>
</template>
