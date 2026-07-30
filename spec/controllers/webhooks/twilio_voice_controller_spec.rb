require 'rails_helper'

RSpec.describe 'Webhooks::TwilioVoiceController', type: :request do
  let(:auth_token) { 'test_auth_token' }
  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_api, account: account, additional_attributes: { phone_number: '+15550009999', twilio_account_sid: 'AC_test' })
  end
  let(:inbox) { channel.inbox }
  let(:agent) { create(:user, account: account, role: :agent) }

  def signed_post(path, params)
    url = "http://www.example.com#{path}"
    signature = Twilio::Security::RequestValidator.new(auth_token).build_signature_for(url, params.stringify_keys)
    post path, params: params, headers: { 'X-Twilio-Signature' => signature }
  end

  around do |example|
    with_modified_env(TWILIO_VOICE_AUTH_TOKEN: auth_token) { example.run }
  end

  describe 'signature verification' do
    it 'rejects requests with a missing or invalid signature' do
      post "/webhooks/twilio_voice/#{channel.additional_attributes['phone_number'].delete_prefix('+')}",
           params: { 'CallSid' => 'CA1', 'From' => '+15551112222', 'To' => channel.additional_attributes['phone_number'] }

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects requests with a tampered signature' do
      path = "/webhooks/twilio_voice/#{channel.additional_attributes['phone_number'].delete_prefix('+')}"
      post path, params: { 'CallSid' => 'CA1', 'From' => '+15551112222', 'To' => channel.additional_attributes['phone_number'] },
                 headers: { 'X-Twilio-Signature' => 'bogus' }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /webhooks/twilio_voice/:phone_number (call_twiml)' do
    let(:phone_digits) { channel.additional_attributes['phone_number'].delete_prefix('+') }
    let(:params) { { 'CallSid' => 'CA_inbound_1', 'From' => '+15551112222', 'To' => channel.additional_attributes['phone_number'] } }

    it 'returns not_found when no channel matches the phone number' do
      signed_post '/webhooks/twilio_voice/19998887777', params
      expect(response).to have_http_status(:not_found)
    end

    context 'when no agent is online' do
      it 'creates the ringing call and renders voicemail TwiML' do
        expect do
          signed_post "/webhooks/twilio_voice/#{phone_digits}", params
        end.to change(VoiceCall, :count).by(1).and change(Message, :count).by(1)

        expect(response.body).to include('<Record')
        expect(response.body).not_to include('<Dial>')

        voice_call = VoiceCall.find_by(provider_call_id: 'CA_inbound_1')
        expect(voice_call.status).to eq('ringing')
        expect(voice_call.conversation.inbox).to eq(inbox)
        expect(voice_call.message.content_type).to eq('voice_call')
      end
    end

    context 'when an inbox member is online' do
      before do
        create(:inbox_member, inbox: inbox, user: agent)
        OnlineStatusTracker.set_status(account.id, agent.id, 'online')
        OnlineStatusTracker.update_presence(account.id, 'User', agent.id)
      end

      it 'renders Dial/Conference TwiML' do
        signed_post "/webhooks/twilio_voice/#{phone_digits}", params

        expect(response.body).to include('<Dial>')
        expect(response.body).to include('<Conference')
        voice_call = VoiceCall.find_by(provider_call_id: 'CA_inbound_1')
        expect(response.body).to include(voice_call.conference_sid)
      end

      it 'schedules a ring-timeout job so an unanswered call falls back to voicemail' do
        expect do
          signed_post "/webhooks/twilio_voice/#{phone_digits}", params
        end.to have_enqueued_job(VoiceRingTimeoutJob).with(kind_of(Integer))
      end
    end

    context 'with a country routing rule' do
      let(:italy_agent) { create(:user, account: account, role: :agent) }
      let(:italy_params) { params.merge('From' => '+390212345678') }

      before do
        create(:inbox_member, inbox: inbox, user: agent)
        create(:inbox_member, inbox: inbox, user: italy_agent)
        OnlineStatusTracker.set_status(account.id, agent.id, 'online')
        OnlineStatusTracker.update_presence(account.id, 'User', agent.id)
        create(:voice_country_route, account: account, inbox: inbox, user: italy_agent, country_name: 'Italy', phone_prefix: '+39')
      end

      it 'goes to voicemail for a routed country when the assigned agent is offline, even if others are online' do
        signed_post "/webhooks/twilio_voice/#{phone_digits}", italy_params

        expect(response.body).to include('<Record')
        expect(response.body).not_to include('<Dial>')
      end

      it 'rings the routed agent once they are online' do
        OnlineStatusTracker.set_status(account.id, italy_agent.id, 'online')
        OnlineStatusTracker.update_presence(account.id, 'User', italy_agent.id)

        signed_post "/webhooks/twilio_voice/#{phone_digits}", italy_params

        expect(response.body).to include('<Dial>')
      end

      it 'stores the matched route agent(s) as eligible_agent_ids on the call, not just the online decision' do
        signed_post "/webhooks/twilio_voice/#{phone_digits}", italy_params

        voice_call = VoiceCall.find_by(provider_call_id: italy_params['CallSid'])
        expect(voice_call.eligible_agent_ids).to eq([italy_agent.id])
      end

      it 'leaves eligible_agent_ids empty for a country with no matching rule' do
        signed_post "/webhooks/twilio_voice/#{phone_digits}", params

        voice_call = VoiceCall.find_by(provider_call_id: params['CallSid'])
        expect(voice_call.eligible_agent_ids).to eq([])
      end

      it 'is unaffected for a country with no routing rule' do
        signed_post "/webhooks/twilio_voice/#{phone_digits}", params

        expect(response.body).to include('<Dial>')
      end
    end
  end

  describe 'POST .../status' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let!(:voice_call) do
      create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact, provider_call_id: 'CA_status_1')
    end
    let(:phone_digits) { channel.additional_attributes['phone_number'].delete_prefix('+') }

    it 'marks a still-ringing call as no_answer on a no-answer callback' do
      signed_post "/webhooks/twilio_voice/#{phone_digits}/status", { 'CallSid' => 'CA_status_1', 'CallStatus' => 'no-answer' }

      expect(voice_call.reload.status).to eq('no-answer')
    end

    it 'does not override a call that already progressed past ringing' do
      voice_call.update!(status: 'in_progress')

      signed_post "/webhooks/twilio_voice/#{phone_digits}/status", { 'CallSid' => 'CA_status_1', 'CallStatus' => 'completed' }

      expect(voice_call.reload.status).to eq('in-progress')
    end
  end

  describe 'POST .../conference_status' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let!(:voice_call) do
      create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                           provider_call_id: 'CA_conf_1', conference_sid: 'voice-conf-1')
    end
    let(:phone_digits) { channel.additional_attributes['phone_number'].delete_prefix('+') }

    it 'marks the call in_progress on conference-start' do
      signed_post "/webhooks/twilio_voice/#{phone_digits}/conference_status",
                  { 'FriendlyName' => 'voice-conf-1', 'StatusCallbackEvent' => 'conference-start' }

      expect(voice_call.reload.status).to eq('in-progress')
      expect(voice_call.started_at).to be_present
    end

    it 'marks the call completed with a duration on conference-end' do
      voice_call.update!(status: 'in_progress', started_at: 30.seconds.ago)

      signed_post "/webhooks/twilio_voice/#{phone_digits}/conference_status",
                  { 'FriendlyName' => 'voice-conf-1', 'StatusCallbackEvent' => 'conference-end' }

      voice_call.reload
      expect(voice_call.status).to eq('completed')
      expect(voice_call.duration_seconds).to be >= 30
    end
  end

  describe 'POST .../recording_status' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let!(:voice_call) do
      create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact, provider_call_id: 'CA_rec_1')
    end
    let(:phone_digits) { channel.additional_attributes['phone_number'].delete_prefix('+') }

    it 'enqueues the recording download job when the recording completes' do
      expect do
        signed_post "/webhooks/twilio_voice/#{phone_digits}/recording_status",
                    { 'CallSid' => 'CA_rec_1', 'RecordingStatus' => 'completed', 'RecordingUrl' => 'https://api.twilio.com/rec/RE1' }
      end.to have_enqueued_job(VoiceRecordingDownloadJob).with(voice_call.id, 'https://api.twilio.com/rec/RE1')
    end

    it 'ignores non-completed recording statuses' do
      expect do
        signed_post "/webhooks/twilio_voice/#{phone_digits}/recording_status",
                    { 'CallSid' => 'CA_rec_1', 'RecordingStatus' => 'in-progress', 'RecordingUrl' => 'https://api.twilio.com/rec/RE1' }
      end.not_to have_enqueued_job(VoiceRecordingDownloadJob)
    end
  end

  describe 'POST .../ring_timeout' do
    let(:phone_digits) { channel.additional_attributes['phone_number'].delete_prefix('+') }

    it 'renders the voicemail TwiML so an unanswered call gets redirected there' do
      signed_post "/webhooks/twilio_voice/#{phone_digits}/ring_timeout", {}

      expect(response.body).to include('<Record')
      expect(response.body).not_to include('<Dial>')
    end
  end
end
