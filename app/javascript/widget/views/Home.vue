<script>
import TeamAvailability from 'widget/components/TeamAvailability.vue';
import ChatInputWrap from 'widget/components/ChatInputWrap.vue';
import { mapActions, mapGetters } from 'vuex';
import { IFrameHelper } from 'widget/helpers/utils';
import { CHATWOOT_ON_START_CONVERSATION } from 'widget/constants/sdkEvents';
import { useRouter } from 'vue-router';
import configMixin from 'widget/mixins/configMixin';
import ArticleContainer from '../components/pageComponents/Home/Article/ArticleContainer.vue';
export default {
  name: 'Home',
  components: {
    ArticleContainer,
    ChatInputWrap,
    TeamAvailability,
  },
  mixins: [configMixin],
  setup() {
    const router = useRouter();
    return { router };
  },
  computed: {
    ...mapGetters({
      availableAgents: 'agent/availableAgents',
      conversationSize: 'conversation/getConversationSize',
      unreadMessageCount: 'conversation/getUnreadMessageCount',
    }),
    // FRESHDESK-SKIN: a first-time visitor types straight into the home card
    // instead of clicking "Start conversation" to reach a message box. With a
    // pre-chat form the form has to come first, so keep the link there.
    showInlineComposer() {
      return !this.conversationSize && !this.preChatFormEnabled;
    },
  },
  methods: {
    ...mapActions('conversation', ['sendMessage', 'sendAttachment']),
    ...mapActions('conversationAttributes', ['getAttributes']),
    openConversation() {
      this.router.replace({ name: 'messages' });
      IFrameHelper.sendMessage({
        event: 'onEvent',
        eventIdentifier: CHATWOOT_ON_START_CONVERSATION,
        data: { hasConversation: false },
      });
    },
    async sendFirstMessage(content) {
      this.openConversation();
      await this.sendMessage({ content });
      this.getAttributes();
    },
    async sendFirstAttachment(attachment) {
      this.openConversation();
      await this.sendAttachment({ attachment });
      this.getAttributes();
    },
    startConversation() {
      if (this.preChatFormEnabled && !this.conversationSize) {
        return this.router.replace({ name: 'prechat-form' });
      }
      return this.router.replace({ name: 'messages' });
    },
  },
};
</script>

<template>
  <div class="z-50 flex flex-col justify-end flex-1 w-full p-4 gap-4">
    <TeamAvailability
      :available-agents="availableAgents"
      :has-conversation="!!conversationSize"
      :unread-count="unreadMessageCount"
      @start-conversation="startConversation"
    >
      <template v-if="showInlineComposer" #default>
        <ChatInputWrap
          class="shadow-sm"
          :on-send-message="sendFirstMessage"
          :on-send-attachment="sendFirstAttachment"
        />
      </template>
    </TeamAvailability>

    <ArticleContainer />
  </div>
</template>
