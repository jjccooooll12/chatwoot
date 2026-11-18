require 'rails_helper'

describe MessageTemplates::Template::EmailCollect do
  context 'when this hook is called' do
    let(:conversation) { create(:conversation) }

    it 'says an agent is coming, then asks for an email as the next message, and flags the conversation' do
      described_class.new(conversation: conversation).perform

      expect(conversation.messages.order(:id).pluck(:content_type, :content)).to eq(
        [['text', 'Thanks for reaching out! A real agent will be with you shortly.'],
         ['text', 'Could you share your email so we can get back to you?']]
      )
      expect(conversation.reload.additional_attributes['email_requested']).to be(true)
    end

    it 'does not ask again when a stale copy of the conversation runs the hook after the flag was saved' do
      stale = Conversation.find(conversation.id)
      described_class.new(conversation: conversation).perform

      described_class.new(conversation: stale).perform

      expect(conversation.messages.count).to eq(2)
    end
  end
end
