class Api::V1::Accounts::CallsController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 100
  PENDING_PROVIDER_CALL_PREFIX = 'pending-'.freeze

  def index
    calls = VoiceCall.joins(:conversation)
                     .where(account_id: Current.account.id)
                     .includes(:contact, :inbox, :conversation, :message, :accepted_by_agent)
                     .order(created_at: :desc)
                     .page(current_page)
                     .per(RESULTS_PER_PAGE)

    render json: {
      payload: calls.map { |call| call_payload(call) },
      meta: {
        count: calls.total_count,
        current_page: current_page,
        total_pages: calls.total_pages
      }
    }
  end

  def conversations
    phone_number = normalize_phone_number(params[:phone_number])
    conversations = matching_conversations(phone_number)

    render json: {
      payload: conversations.map { |conversation| ticket_payload(conversation) }
    }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def ticket
    voice_call = VoiceCall.where(account_id: Current.account.id).find(params[:id])
    authorize voice_call.inbox, :show?

    conversation = case ticket_params[:ticket_action]
                   when 'new'
                     voice_call.conversation || create_conversation_for_call!(voice_call)
                   when 'existing'
                     find_conversation!(ticket_params[:conversation_id].presence)
                   else
                     raise ArgumentError, 'Choose Create new ticket or Add to existing ticket.'
                   end

    attach_call_to_conversation!(voice_call, conversation)
    render json: { call: call_payload(voice_call.reload), conversation: conversation_payload(conversation) }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    fetch_outbound_resources!
    ensure_twilio_voice_inbox!
    return if performed?

    voice_call = create_outbound_call_record!
    twilio_call = create_twilio_outbound_call!(voice_call)
    voice_call.update!(provider_call_id: twilio_call.sid)
    voice_call.message&.send_update_event

    render json: outbound_payload(voice_call)
  rescue Twilio::REST::RestError => e
    voice_call&.transition_to!(status: 'failed', ended_at: Time.current, end_reason: e.code || 'twilio_error')
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def current_page
    params[:page].presence || 1
  end

  def call_params
    params.permit(:contact_id, :inbox_id, :conversation_id, :phone_number, :ticket_action)
  end

  def ticket_params
    params.permit(:ticket_action, :conversation_id)
  end

  def fetch_outbound_resources!
    @inbox = Current.account.inboxes.includes(:channel).find(call_params[:inbox_id])
    authorize @inbox, :show?

    @contact = Current.account.contacts.find(call_params[:contact_id])
    @to_number = normalize_phone_number(call_params[:phone_number].presence || @contact.phone_number)
    @conversation = fetch_or_create_conversation!
    @contact = @conversation.contact if call_params[:conversation_id].present?
  end

  def fetch_or_create_conversation!
    conversation_id = call_params[:conversation_id].presence
    return find_conversation!(conversation_id) if conversation_id

    unless call_params[:ticket_action] == 'new'
      raise ArgumentError, 'Choose Create new ticket or Add to existing ticket before starting a call.'
    end

    contact_inbox = ContactInboxBuilder.new(
      contact: @contact,
      inbox: @inbox,
      source_id: "voice:#{@to_number}"
    ).perform

    ConversationBuilder.new(
      params: ActionController::Parameters.new(status: 'open'),
      contact_inbox: contact_inbox
    ).perform
  end

  def find_conversation!(value)
    Current.account.conversations.find_by(display_id: value) ||
      Current.account.conversations.find_by("conversations.additional_attributes->>'ticket_number' = ?", value.to_s) ||
      Current.account.conversations.find(value)
  end

  def normalize_phone_number(number)
    normalized = number.to_s.gsub(/[^\d+]/, '')
    normalized = "+#{normalized.delete_prefix('00')}" if normalized.start_with?('00')
    normalized = "+#{normalized}" unless normalized.start_with?('+')
    raise ArgumentError, 'Enter a valid phone number.' unless normalized.match?(/\A\+[1-9]\d{1,14}\z/)

    normalized
  end

  def ensure_twilio_voice_inbox!
    return if @inbox.channel_type == 'Channel::Api' && twilio_voice_attributes.values_at(*required_twilio_keys).all?(&:present?)

    render json: { error: 'Selected inbox is not configured for outbound Twilio voice calls.' }, status: :unprocessable_entity
  end

  def required_twilio_keys
    %w[phone_number twilio_account_sid twilio_api_key_sid twilio_twiml_app_sid]
  end

  def twilio_voice_attributes
    @twilio_voice_attributes ||= @inbox.channel.additional_attributes || {}
  end

  def create_outbound_call_record!
    label = outgoing_call_label
    message = @conversation.messages.create!(
      account: Current.account,
      inbox: @inbox,
      sender: Current.user,
      message_type: :outgoing,
      content_type: :voice_call,
      content: label
    )

    @conversation.update_columns( # rubocop:disable Rails/SkipsModelValidations
      additional_attributes: @conversation.additional_attributes.merge('mail_subject' => label),
      assignee_id: Current.user.id
    )

    VoiceCall.create!(
      account: Current.account,
      inbox: @inbox,
      conversation: @conversation,
      contact: @contact,
      message: message,
      provider_call_id: "#{PENDING_PROVIDER_CALL_PREFIX}#{SecureRandom.uuid}",
      direction: 'outgoing',
      status: 'ringing',
      conference_sid: "voice-#{SecureRandom.hex(8)}",
      from_number: twilio_voice_attributes['phone_number'],
      to_number: @to_number,
      accepted_by_agent_id: Current.user.id,
      eligible_agent_ids: [Current.user.id]
    )
  end

  def create_twilio_outbound_call!(voice_call)
    twilio_client.calls.create(
      to: voice_call.to_number,
      from: voice_call.from_number,
      url: voice_webhook_outbound_url(
        phone_number: voice_call.from_number.delete_prefix('+'),
        conference_sid: voice_call.conference_sid
      ),
      method: 'POST',
      status_callback: voice_webhook_outbound_status_url(
        phone_number: voice_call.from_number.delete_prefix('+'),
        conference_sid: voice_call.conference_sid
      ),
      status_callback_method: 'POST',
      status_callback_event: %w[initiated ringing answered completed]
    )
  end

  def twilio_client
    @twilio_client ||= ::Twilio::REST::Client.new(
      twilio_voice_attributes['twilio_api_key_sid'],
      ENV.fetch('TWILIO_VOICE_API_KEY_SECRET'),
      twilio_voice_attributes['twilio_account_sid']
    )
  end

  def outbound_payload(voice_call)
    {
      call_sid: voice_call.provider_call_id,
      conversation_id: voice_call.conversation.display_id,
      call: call_payload(voice_call)
    }
  end

  def call_payload(call)
    {
      id: call.id,
      provider_call_id: call.provider_call_id,
      provider: 'twilio',
      direction: normalized_direction(call.direction),
      status: call.display_status,
      duration_seconds: call.duration_seconds,
      end_reason: call.end_reason,
      conference_sid: call.conference_sid,
      accepted_by_agent_id: call.accepted_by_agent_id,
      started_at: call.started_at&.to_i,
      ended_at: call.ended_at&.to_i,
      created_at: call.created_at.to_i,
      from_number: call.from_number,
      to_number: call.to_number,
      recording_url: call.recording.attached? ? url_for(call.recording) : nil,
      contact: call.contact.push_event_data,
      agent: call.accepted_by_agent&.push_event_data,
      inbox: { id: call.inbox.id, name: call.inbox.name },
      conversation: conversation_payload(call.conversation),
      message_id: call.message_id
    }
  end

  def outgoing_call_label
    display_name = if @contact.name.present? && @contact.name != @to_number
                     @contact.name
                   else
                     @to_number
                   end
    "Outgoing call to #{display_name}"
  end

  def normalized_direction(direction)
    direction == 'outgoing' ? 'outbound' : 'inbound'
  end

  def matching_conversations(phone_number)
    ticket_id = params[:ticket_id].to_s.strip
    scope = Current.account.conversations.includes(:contact, :inbox).order(updated_at: :desc)

    if ticket_id.present?
      return scope.where(
        'conversations.display_id::text = :ticket_id OR conversations.additional_attributes->>\'ticket_number\' = :ticket_id',
        ticket_id: ticket_id
      ).limit(20)
    end

    contact_ids = Current.account.contacts.where(phone_number: phone_number).select(:id)
    scope.where(contact_id: contact_ids).limit(20)
  end

  def ticket_payload(conversation)
    {
      id: conversation.id,
      display_id: conversation.display_id,
      ticket_number: conversation.ticket_number,
      status: conversation.status,
      subject: conversation.additional_attributes['mail_subject'],
      updated_at: conversation.updated_at.to_i,
      inbox: {
        id: conversation.inbox.id,
        name: conversation.inbox.name
      },
      contact: {
        id: conversation.contact.id,
        name: conversation.contact.name,
        phone_number: conversation.contact.phone_number,
        email: conversation.contact.email
      }
    }
  end

  def create_conversation_for_call!(voice_call)
    contact_inbox = ContactInboxBuilder.new(
      contact: voice_call.contact,
      inbox: voice_call.inbox,
      source_id: "voice:#{voice_call.to_number}"
    ).perform

    ConversationBuilder.new(
      params: ActionController::Parameters.new(status: 'open'),
      contact_inbox: contact_inbox
    ).perform
  end

  def attach_call_to_conversation!(voice_call, conversation)
    label = voice_call.outgoing? ? voice_call.outgoing_label : voice_call.answered_label
    old_conversation = voice_call.conversation
    message = voice_call.message || conversation.messages.build(
      account: Current.account,
      sender: Current.user,
      message_type: :outgoing,
      content_type: :voice_call
    )

    message.update!(
      account: Current.account,
      inbox: conversation.inbox,
      conversation: conversation,
      content: label
    )

    voice_call.update!(
      conversation: conversation,
      contact: conversation.contact,
      message: message
    )

    conversation.update_columns( # rubocop:disable Rails/SkipsModelValidations
      additional_attributes: conversation.additional_attributes.merge('mail_subject' => label),
      assignee_id: Current.user.id
    )
    message.send_update_event
    old_conversation.destroy! if old_conversation && old_conversation != conversation && old_conversation.messages.reload.empty?
  end

  def conversation_payload(conversation)
    return nil unless conversation

    {
      id: conversation.id,
      display_id: conversation.display_id,
      ticket_number: conversation.ticket_number,
      additional_attributes: conversation.additional_attributes
    }
  end
end
