require 'rails_helper'

RSpec.describe VoiceRingTimeoutJob do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account, additional_attributes: { twilio_account_sid: 'AC_test' }) }
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:voice_call) do
    create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                         provider_call_id: 'CA_timeout_1', to_number: '+14358000172')
  end

  around do |example|
    with_modified_env(TWILIO_VOICE_AUTH_TOKEN: 'test_token') { example.run }
  end

  it 'does nothing if the call already progressed past ringing' do
    voice_call.update!(status: 'in_progress')
    expect(Twilio::REST::Client).not_to receive(:new)

    described_class.new.perform(voice_call.id)
  end

  it 'redirects the live call to the ring_timeout TwiML if still ringing' do
    calls_resource = instance_double(Twilio::REST::Api::V2010::CallInstance)
    client = instance_double(Twilio::REST::Client)
    allow(Twilio::REST::Client).to receive(:new).with('AC_test', 'test_token').and_return(client)
    allow(client).to receive(:calls).with('CA_timeout_1').and_return(calls_resource)
    expect(calls_resource).to receive(:update).with(
      url: a_string_matching(%r{/webhooks/twilio_voice/14358000172/ring_timeout\z}),
      method: 'POST'
    )

    described_class.new.perform(voice_call.id)
  end

  it 'does not raise if the call already ended on Twilio\'s side' do
    client = instance_double(Twilio::REST::Client)
    calls_resource = instance_double(Twilio::REST::Api::V2010::CallInstance)
    allow(Twilio::REST::Client).to receive(:new).and_return(client)
    allow(client).to receive(:calls).and_return(calls_resource)
    allow(calls_resource).to receive(:update).and_raise(Twilio::REST::RestError.new('not in-progress', double(status_code: 400, body: {}))) # rubocop:disable RSpec/VerifiedDoubles

    expect { described_class.new.perform(voice_call.id) }.not_to raise_error
  end
end
