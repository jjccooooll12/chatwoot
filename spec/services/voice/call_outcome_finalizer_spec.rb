require 'rails_helper'

RSpec.describe Voice::CallOutcomeFinalizer do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account) }
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:from_number) { '+15550001111' }

  def build_call(status:, recording: false, from: from_number)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    message = create(:message, account: account, conversation: conversation, sender: contact,
                                content_type: :voice_call, content: 'Incoming call')
    voice_call = create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: contact,
                                      message: message, status: status, from_number: from)
    attach_recording!(voice_call) if recording
    voice_call
  end

  def attach_recording!(voice_call)
    voice_call.recording.attach(io: Rails.root.join('spec/assets/sample.mp3').open, filename: 'sample.mp3', content_type: 'audio/mpeg')
  end

  describe '#perform' do
    it 'relabels an abandoned call and leaves it alone when no sibling exists' do
      call = build_call(status: 'no_answer')

      described_class.new(voice_call: call).perform

      expect(call.message.reload.content).to eq('Abandoned call')
      expect(call.conversation.reload).to be_open
    end

    it 'relabels a voicemail when no sibling exists' do
      call = build_call(status: 'no_answer', recording: true)

      described_class.new(voice_call: call).perform

      expect(call.message.reload.content).to eq('Voicemail')
      expect(call.conversation.reload).to be_open
    end

    it "updates the conversation's mail_subject too, not just the message content" do
      # Message#ensure_conversation_subject sets additional_attributes['mail_subject']
      # once at creation time and it takes priority over message.content in the
      # ticket list's subject — relabeling only the message would leave the list
      # showing "Incoming call" forever even though the bubble is correct.
      call = build_call(status: 'no_answer')
      call.conversation.update_columns(additional_attributes: { 'mail_subject' => 'Incoming call' })

      described_class.new(voice_call: call).perform

      expect(call.conversation.reload.additional_attributes['mail_subject']).to eq('Abandoned call')
    end

    it 'merges two abandoned calls for the same number, primary = the newest' do
      older = build_call(status: 'no_answer')
      described_class.new(voice_call: older).perform
      newer = build_call(status: 'no_answer')

      described_class.new(voice_call: newer).perform

      expect(newer.conversation.reload).to be_open
      expect(older.conversation.reload).to be_resolved
      expect(older.conversation.additional_attributes['merged_into_display_id']).to eq(newer.conversation.display_id)
    end

    it 'merges a voicemail over an existing open abandoned sibling, primary = the voicemail' do
      abandoned = build_call(status: 'no_answer')
      described_class.new(voice_call: abandoned).perform
      voicemail = build_call(status: 'no_answer', recording: true)

      described_class.new(voice_call: voicemail).perform

      expect(voicemail.conversation.reload).to be_open
      expect(voicemail.message.reload.content).to eq('Voicemail')
      expect(abandoned.conversation.reload).to be_resolved
      expect(abandoned.conversation.additional_attributes['merged_into_display_id']).to eq(voicemail.conversation.display_id)
    end

    it 'does not merge two voicemails together' do
      first_voicemail = build_call(status: 'no_answer', recording: true)
      described_class.new(voice_call: first_voicemail).perform
      second_voicemail = build_call(status: 'no_answer', recording: true)

      described_class.new(voice_call: second_voicemail).perform

      expect(first_voicemail.conversation.reload).to be_open
      expect(second_voicemail.conversation.reload).to be_open
      expect(second_voicemail.message.reload.content).to eq('Voicemail')
    end

    it 'merges an abandoned call into the most recent open voicemail sibling, not a stray abandoned one' do
      voicemail = build_call(status: 'no_answer', recording: true)
      described_class.new(voice_call: voicemail).perform
      stray_abandoned = build_call(status: 'no_answer')
      described_class.new(voice_call: stray_abandoned).perform # merges into the voicemail, per the rule above
      newest_abandoned = build_call(status: 'no_answer')

      described_class.new(voice_call: newest_abandoned).perform

      expect(voicemail.conversation.reload).to be_open
      expect(newest_abandoned.conversation.reload).to be_resolved
      expect(newest_abandoned.conversation.additional_attributes['merged_into_display_id']).to eq(voicemail.conversation.display_id)
    end

    it 'is idempotent — a second run after the label already matches does not attempt another merge' do
      call = build_call(status: 'no_answer')
      described_class.new(voice_call: call).perform
      expect(Conversations::MergeService).not_to receive(:new)

      described_class.new(voice_call: call).perform
    end

    it 'ignores a sibling from a different phone number' do
      other_number_call = build_call(status: 'no_answer', from: '+19995551234')
      described_class.new(voice_call: other_number_call).perform
      call = build_call(status: 'no_answer')

      described_class.new(voice_call: call).perform

      expect(call.conversation.reload).to be_open
      expect(other_number_call.conversation.reload).to be_open
    end

    it 'ignores an answered (in_progress) call for the same number' do
      answered = build_call(status: 'in_progress')
      call = build_call(status: 'no_answer')

      described_class.new(voice_call: call).perform

      expect(call.conversation.reload).to be_open
      expect(answered.conversation.reload).to be_open
    end

    it 'relabels a late-arriving voicemail but does not re-promote an already-merged-away conversation' do
      a = build_call(status: 'no_answer')
      described_class.new(voice_call: a).perform
      b = build_call(status: 'no_answer')
      described_class.new(voice_call: b).perform # merges: primary = b, secondary = a

      expect(a.conversation.reload).to be_resolved
      expect(b.conversation.reload).to be_open

      attach_recording!(a)
      described_class.new(voice_call: a).perform

      expect(a.message.reload.content).to eq('Voicemail')
      expect(a.conversation.reload).to be_resolved
      expect(b.conversation.reload).to be_open
    end
  end
end
