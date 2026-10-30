require 'rails_helper'

describe MessageTemplates::Template::EmailCollect do
  context 'when this hook is called' do
    let(:conversation) { create(:conversation) }

    it 'asks for an email in one plain text message and flags the conversation' do
      described_class.new(conversation: conversation).perform

      expect(conversation.messages.count).to eq(1)
      expect(conversation.messages.last.content_type).to eq('text')
      expect(conversation.messages.last.content).to include('Could you share your email')
      expect(conversation.reload.additional_attributes['email_requested']).to be(true)
    end
  end
end
