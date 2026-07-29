<script>
import { mapGetters } from 'vuex';
import MentionBox from '../mentions/MentionBox.vue';
import { frontendURL } from 'dashboard/helper/URLHelper';

export default {
  components: { MentionBox },
  props: {
    searchKey: {
      type: String,
      default: '',
    },
  },
  emits: ['replace'],
  computed: {
    ...mapGetters({
      cannedMessages: 'getCannedResponses',
      accountId: 'getCurrentAccountId',
    }),
    items() {
      return this.cannedMessages.map(cannedMessage => ({
        label: cannedMessage.short_code,
        key: cannedMessage.short_code,
        description: cannedMessage.content,
      }));
    },
    manageUrl() {
      return frontendURL(
        `accounts/${this.accountId}/settings/canned-response/list`
      );
    },
  },
  watch: {
    searchKey() {
      this.fetchCannedResponses();
    },
  },
  mounted() {
    this.fetchCannedResponses();
  },
  methods: {
    fetchCannedResponses() {
      this.$store.dispatch('getCannedResponse', { searchKey: this.searchKey });
    },
    handleMentionClick(item = {}) {
      this.$emit('replace', item.description);
    },
  },
};
</script>

<template>
  <MentionBox :items="items" @mention-select="handleMentionClick">
    <template #header>
      <div
        class="mb-1 flex items-center justify-between border-b border-n-strong px-2 py-1.5"
      >
        <span
          class="text-xxs font-semibold uppercase tracking-wide text-n-slate-11"
        >
          {{ $t('CONVERSATION.REPLYBOX.CANNED_RESPONSES_HEADER') }}
        </span>
        <a
          :href="manageUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="text-xs font-medium text-n-blue-11 hover:underline"
        >
          {{ $t('CONVERSATION.REPLYBOX.CANNED_RESPONSES_CREATE_NEW') }}
        </a>
      </div>
    </template>
  </MentionBox>
</template>
