<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  DropdownContainer,
  DropdownBody,
  DropdownItem,
} from 'next/dropdown-menu/base';
import voiceCountryRoutesAPI from 'dashboard/api/voiceCountryRoutes';

const { t } = useI18n();
const store = useStore();

const inboxes = useMapGetter('inboxes/getInboxes');
const agents = useMapGetter('agents/getAgents');

const voiceInbox = computed(() => inboxes.value.find(i => i.name === 'Voice'));

const routes = ref([]);
const isLoading = ref(false);
const countryName = ref('');
const phonePrefix = ref('');
const selectedAgentId = ref('');

const selectedAgentName = computed(() => {
  const agent = agents.value.find(a => a.id === selectedAgentId.value);
  return agent?.name;
});

const fetchRoutes = async () => {
  if (!voiceInbox.value) return;
  isLoading.value = true;
  try {
    const response = await voiceCountryRoutesAPI.index(voiceInbox.value.id);
    routes.value = response.data;
  } catch (error) {
    useAlert(t('VOICE_ROUTING.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const addRoute = async () => {
  if (!countryName.value || !phonePrefix.value || !selectedAgentId.value) {
    return;
  }
  try {
    await voiceCountryRoutesAPI.create(voiceInbox.value.id, {
      countryName: countryName.value,
      phonePrefix: phonePrefix.value,
      userId: Number(selectedAgentId.value),
    });
    countryName.value = '';
    phonePrefix.value = '';
    selectedAgentId.value = '';
    await fetchRoutes();
  } catch (error) {
    const message =
      error?.response?.data?.errors?.join(', ') || t('VOICE_ROUTING.ADD_ERROR');
    useAlert(message);
  }
};

const removeRoute = async route => {
  try {
    await voiceCountryRoutesAPI.delete(voiceInbox.value.id, route.id);
    await fetchRoutes();
  } catch (error) {
    useAlert(t('VOICE_ROUTING.REMOVE_ERROR'));
  }
};

const groupedRoutes = computed(() => {
  const groups = {};
  routes.value.forEach(route => {
    const key = `${route.country_name}__${route.phone_prefix}`;
    groups[key] ||= {
      label: `${route.country_name} (${route.phone_prefix})`,
      countryName: route.country_name,
      phonePrefix: route.phone_prefix,
      entries: [],
    };
    groups[key].entries.push(route);
  });
  return Object.values(groups);
});

onMounted(async () => {
  if (!agents.value.length) {
    await store.dispatch('agents/get');
  }
  await fetchRoutes();
});
</script>

<template>
  <SettingsLayout :is-loading="isLoading" :no-records-found="false">
    <template #header>
      <BaseSettingsHeader
        :title="t('VOICE_ROUTING.TITLE')"
        :description="t('VOICE_ROUTING.DESCRIPTION')"
      />
    </template>
    <template #body>
      <div v-if="!voiceInbox" class="p-4 text-n-slate-11">
        {{ t('VOICE_ROUTING.NO_VOICE_INBOX') }}
      </div>
      <div v-else class="flex flex-col gap-6 w-full max-w-2xl">
        <div class="flex flex-col gap-2">
          <div
            v-for="group in groupedRoutes"
            :key="group.countryName + group.phonePrefix"
            class="border border-n-weak rounded-lg p-3"
          >
            <div class="font-medium text-n-slate-12">{{ group.label }}</div>
            <div
              v-for="entry in group.entries"
              :key="entry.id"
              class="flex items-center justify-between mt-1 text-sm"
            >
              <span class="text-n-slate-11">{{ entry.user_name }}</span>
              <NextButton
                size="xs"
                color="ruby"
                variant="ghost"
                icon="i-lucide-trash-2"
                :label="t('VOICE_ROUTING.REMOVE')"
                @click="removeRoute(entry)"
              />
            </div>
          </div>
          <p v-if="!groupedRoutes.length" class="text-n-slate-11 text-sm">
            {{ t('VOICE_ROUTING.EMPTY') }}
          </p>
        </div>

        <div class="border-t border-n-weak pt-4">
          <h4 class="font-medium mb-2">{{ t('VOICE_ROUTING.ADD_TITLE') }}</h4>
          <p class="text-n-slate-11 text-sm mb-3">
            {{ t('VOICE_ROUTING.ADD_DESCRIPTION') }}
          </p>
          <div class="flex flex-wrap gap-2 items-end">
            <div class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-11">{{
                t('VOICE_ROUTING.COUNTRY_NAME')
              }}</label>
              <input
                v-model="countryName"
                type="text"
                :placeholder="t('VOICE_ROUTING.COUNTRY_NAME_PLACEHOLDER')"
                class="reset-base h-[34px] border border-n-weak rounded-md px-2 text-sm"
              />
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-11">{{
                t('VOICE_ROUTING.PHONE_PREFIX')
              }}</label>
              <input
                v-model="phonePrefix"
                type="text"
                :placeholder="t('VOICE_ROUTING.PHONE_PREFIX_PLACEHOLDER')"
                class="reset-base h-[34px] border border-n-weak rounded-md px-2 text-sm w-24"
              />
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-11">{{
                t('VOICE_ROUTING.AGENT')
              }}</label>
              <DropdownContainer class="shrink-0">
                <template #trigger="{ toggle }">
                  <NextButton
                    size="sm"
                    color="slate"
                    variant="faded"
                    icon="i-lucide-chevron-down"
                    trailing-icon
                    :label="
                      selectedAgentName || t('VOICE_ROUTING.SELECT_AGENT')
                    "
                    @click="toggle"
                  />
                </template>
                <DropdownBody class="min-w-40 z-20">
                  <DropdownItem
                    v-for="agent in agents"
                    :key="agent.id"
                    :label="agent.name"
                    class="cursor-pointer"
                    @click="selectedAgentId = agent.id"
                  />
                </DropdownBody>
              </DropdownContainer>
            </div>
            <NextButton
              :label="t('VOICE_ROUTING.ADD')"
              size="sm"
              @click="addRoute"
            />
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
