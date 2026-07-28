<script setup>
import { computed } from 'vue';
import { frontendURL } from 'dashboard/helper/URLHelper';
import countries from 'shared/constants/countries';
import { dynamicTime } from 'shared/helpers/timeHelper';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Flag from 'dashboard/components-next/flag/Flag.vue';

const props = defineProps({
  id: {
    type: [String, Number],
    default: 0,
  },
  email: {
    type: String,
    default: '',
  },
  phone: {
    type: String,
    default: '',
  },
  name: {
    type: String,
    default: '',
  },
  thumbnail: {
    type: String,
    default: '',
  },
  accountId: {
    type: [String, Number],
    default: 0,
  },
  additionalAttributes: {
    type: Object,
    default: () => ({}),
  },
  updatedAt: {
    type: Number,
    default: 0,
  },
});

const navigateTo = computed(() => {
  return frontendURL(`accounts/${props.accountId}/contacts/${props.id}`);
});

const countriesMap = computed(() => {
  return countries.reduce((acc, country) => {
    acc[country.id] = country;
    return acc;
  }, {});
});

const updatedAtTime = computed(() => {
  if (!props.updatedAt) return '';
  return dynamicTime(props.updatedAt);
});

const countryDetails = computed(() => {
  const { country, countryCode, city } = props.additionalAttributes;

  if (!country && !countryCode) return null;

  const activeCountry =
    countriesMap.value[country] || countriesMap.value[countryCode];

  if (!activeCountry) return null;

  return {
    countryCode: activeCountry.id,
    city: city ? `${city},` : null,
    name: activeCountry.name,
  };
});

const formattedLocation = computed(() => {
  if (!countryDetails.value) return '';

  return [countryDetails.value.city, countryDetails.value.name]
    .filter(Boolean)
    .join(' ');
});
</script>

<template>
  <router-link :to="navigateTo">
    <div
      class="flex items-start gap-3 rounded-lg border border-fd-border bg-fd-surface px-4 py-3 transition-colors hover:border-fd-primary/40 hover:bg-fd-background"
    >
      <Avatar
        :name="name"
        :src="thumbnail"
        :size="36"
        rounded-full
        class="mt-0.5 flex-shrink-0"
      />
      <div class="min-w-0 flex w-full flex-col items-start gap-1">
        <div class="flex w-full min-w-0 items-center justify-between gap-2">
          <h5
            class="m-0 min-w-0 truncate text-[13px] font-semibold leading-5 text-fd-text"
          >
            {{ name }}
          </h5>
          <span
            v-if="updatedAtTime"
            class="shrink-0 text-xs leading-5 text-fd-muted"
          >
            {{ $t('SEARCH.UPDATED_AT', { time: updatedAtTime }) }}
          </span>
        </div>
        <div
          class="m-0 flex min-w-0 flex-wrap items-center gap-x-1.5 gap-y-1 text-xs leading-5 text-fd-muted"
        >
          <span v-if="email" class="min-w-0 truncate" :title="email">
            {{ email }}
          </span>

          <span v-if="email && phone">
            {{ $t('CHAT_LIST.FRESHDESK_CARD.SEPARATOR') }}
          </span>

          <span v-if="phone" :title="phone" class="min-w-0 truncate">
            {{ phone }}
          </span>

          <span v-if="(email || phone) && countryDetails">
            {{ $t('CHAT_LIST.FRESHDESK_CARD.SEPARATOR') }}
          </span>

          <span
            v-if="countryDetails"
            class="flex min-w-0 items-center gap-1 truncate"
          >
            <Flag
              :country="countryDetails.countryCode"
              class="size-3 shrink-0"
            />
            <span class="min-w-0 truncate">{{ formattedLocation }}</span>
          </span>
        </div>
      </div>
    </div>
  </router-link>
</template>
