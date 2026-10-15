<script>
import { validEmailsByComma } from './helpers/emailHeadHelper';
import { useVuelidate } from '@vuelidate/core';

export default {
  props: {
    fromName: {
      type: String,
      default: '',
    },
    fromEmail: {
      type: String,
      default: '',
    },
    ccEmails: {
      type: String,
      default: '',
    },
    bccEmails: {
      type: String,
      default: '',
    },
    toEmails: {
      type: String,
      default: '',
    },
  },
  emits: ['update:bccEmails', 'update:ccEmails', 'update:toEmails'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      // Password managers offer to fill anything that looks like a login, and
      // put their icon in the field to say so. These are the mail fields of a
      // reply, so there is nothing to fill: LastPass's documented opt-out, on
      // the input itself, which is the only place it reads it.
      passwordManagerIgnore: { 'data-lpignore': 'true' },
      showCc: false,
      showBcc: false,
      ccEmailsVal: '',
      bccEmailsVal: '',
      toEmailsVal: '',
    };
  },
  watch: {
    bccEmails(newVal) {
      if (newVal !== this.bccEmailsVal) {
        this.bccEmailsVal = newVal;
      }
      if (newVal) this.showBcc = true;
    },
    ccEmails(newVal) {
      if (newVal !== this.ccEmailsVal) {
        this.ccEmailsVal = newVal;
      }
      if (newVal) this.showCc = true;
    },
    toEmails(newVal) {
      if (newVal !== this.toEmailsVal) {
        this.toEmailsVal = newVal;
      }
    },
  },
  mounted() {
    this.ccEmailsVal = this.ccEmails;
    this.bccEmailsVal = this.bccEmails;
    this.toEmailsVal = this.toEmails;
    // Cc and Bcc are folded away behind the buttons on the To row, unless the
    // reply already carries addresses in them.
    this.showCc = Boolean(this.ccEmails);
    this.showBcc = Boolean(this.bccEmails);
  },
  validations: {
    ccEmailsVal: {
      hasValidEmails(value) {
        return validEmailsByComma(value);
      },
    },
    bccEmailsVal: {
      hasValidEmails(value) {
        return validEmailsByComma(value);
      },
    },
    toEmailsVal: {
      hasValidEmails(value) {
        return validEmailsByComma(value);
      },
    },
  },
  methods: {
    onBlur() {
      this.v$.$touch();
      this.$emit('update:bccEmails', this.bccEmailsVal);
      this.$emit('update:ccEmails', this.ccEmailsVal);
      this.$emit('update:toEmails', this.toEmailsVal);
    },
  },
};
</script>

<template>
  <!-- FRESHDESK-SKIN: "From : / To :" rows above a divider, like Freshdesk. -->
  <div class="mb-3 border-b border-fd-border pb-2 pt-1">
    <div v-if="fromEmail" class="mail-row">
      <span class="mail-label">{{ $t('EMAIL_HEADER.FROM') }}</span>
      <span class="min-w-0 truncate text-[13px] leading-8">
        <span class="font-semibold text-fd-text">{{ fromName }}</span>
        <span class="text-fd-muted"> ({{ fromEmail }})</span>
      </span>
    </div>
    <div
      v-if="toEmails"
      class="mail-row"
      :class="{ error: v$.toEmailsVal.$error }"
    >
      <span class="mail-label">{{ $t('EMAIL_HEADER.TO') }}</span>
      <div class="m-0 min-w-0 flex-1 whitespace-nowrap rounded-none">
        <woot-input
          v-model="v$.toEmailsVal.$model"
          type="text"
          :input-attributes="passwordManagerIgnore"
          class="[&>input]:!mb-0 [&>input]:border-transparent [&>input]:!outline-none [&>input]:h-8 [&>input]:!text-[13px] [&>input]:!font-semibold [&>input]:!text-fd-text [&>input]:!px-0 [&>input]:!border-0 [&>input]:border-none [&>input]:!bg-transparent dark:[&>input]:!bg-transparent"
          :class="{ error: v$.toEmailsVal.$error }"
          :placeholder="$t('CONVERSATION.REPLYBOX.EMAIL_HEAD.CC.PLACEHOLDER')"
          @blur="onBlur"
        />
      </div>
      <button
        v-if="!showCc"
        type="button"
        class="mail-toggle"
        @click="showCc = true"
      >
        {{ $t('EMAIL_HEADER.CC') }}
      </button>
      <button
        v-if="!showBcc"
        type="button"
        class="mail-toggle"
        @click="showBcc = true"
      >
        {{ $t('EMAIL_HEADER.BCC') }}
      </button>
    </div>
    <div v-if="showCc">
      <div class="mail-row" :class="{ error: v$.ccEmailsVal.$error }">
        <span class="mail-label">{{ $t('EMAIL_HEADER.CC') }}</span>
        <div class="m-0 min-w-0 flex-1 whitespace-nowrap rounded-none">
          <woot-input
            v-model="v$.ccEmailsVal.$model"
            class="[&>input]:!mb-0 [&>input]:border-transparent [&>input]:!outline-none [&>input]:h-8 [&>input]:!text-[13px] [&>input]:!font-semibold [&>input]:!text-fd-text [&>input]:!px-0 [&>input]:!border-0 [&>input]:border-none [&>input]:!bg-transparent dark:[&>input]:!bg-transparent"
            type="text"
            :input-attributes="passwordManagerIgnore"
            :class="{ error: v$.ccEmailsVal.$error }"
            :placeholder="$t('CONVERSATION.REPLYBOX.EMAIL_HEAD.CC.PLACEHOLDER')"
            @blur="onBlur"
          />
        </div>
      </div>
      <span v-if="v$.ccEmailsVal.$error" class="message">
        {{ $t('CONVERSATION.REPLYBOX.EMAIL_HEAD.CC.ERROR') }}
      </span>
    </div>
    <div v-if="showBcc">
      <div class="mail-row" :class="{ error: v$.bccEmailsVal.$error }">
        <span class="mail-label">{{ $t('EMAIL_HEADER.BCC') }}</span>
        <div class="m-0 min-w-0 flex-1 whitespace-nowrap rounded-none">
          <woot-input
            v-model="v$.bccEmailsVal.$model"
            type="text"
            :input-attributes="passwordManagerIgnore"
            class="[&>input]:!mb-0 [&>input]:border-transparent [&>input]:!outline-none [&>input]:h-8 [&>input]:!text-[13px] [&>input]:!font-semibold [&>input]:!text-fd-text [&>input]:!px-0 [&>input]:!border-0 [&>input]:border-none [&>input]:!bg-transparent dark:[&>input]:!bg-transparent"
            :class="{ error: v$.bccEmailsVal.$error }"
            :placeholder="
              $t('CONVERSATION.REPLYBOX.EMAIL_HEAD.BCC.PLACEHOLDER')
            "
            @blur="onBlur"
          />
        </div>
      </div>
      <span v-if="v$.bccEmailsVal.$error" class="message">
        {{ $t('CONVERSATION.REPLYBOX.EMAIL_HEAD.BCC.ERROR') }}
      </span>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.message {
  @apply text-sm text-n-ruby-8;
}

.mail-row {
  @apply flex items-center gap-2;
}

.mail-label {
  @apply w-14 shrink-0 text-[13px] leading-8 text-fd-muted;

  &::after {
    content: ' :';
  }
}

.mail-toggle {
  @apply rounded px-1 text-xs font-semibold text-fd-action hover:underline;
}

.mail-row.error .mail-label {
  @apply text-n-ruby-8;
}
</style>
