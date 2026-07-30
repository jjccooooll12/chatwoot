require 'rails_helper'

RSpec.describe VoiceCallOutcomeCheckJob do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account) }
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) do
    create(:message, account: account, conversation: conversation, sender: conversation.contact,
                      content_type: :voice_call, content: 'Incoming call')
  end
  let(:voice_call) do
    create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                         message: message, status: 'no_answer')
  end

  it 'finalizes the call outcome' do
    described_class.perform_now(voice_call.id)

    expect(message.reload.content).to eq('Abandoned call')
  end

  it 'is a no-op when the voice call no longer exists' do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
