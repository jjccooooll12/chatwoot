class Api::V1::Widget::BaseController < ApplicationController
  include SwitchLocale
  include WebsiteTokenHelper

  before_action :set_web_widget
  before_action :set_contact

  private

  def conversations
    if @contact_inbox.hmac_verified?
      verified_contact_inbox_ids = @contact.contact_inboxes.where(inbox_id: auth_token_params[:inbox_id], hmac_verified: true).map(&:id)
      @conversations = @contact.conversations.where(contact_inbox_id: verified_contact_inbox_ids)
    else
      @conversations = @contact_inbox.conversations.where(inbox_id: auth_token_params[:inbox_id])
    end
  end

  # A returning visitor's message continues their last conversation, unless
  # it's gone cold — more than STALE_CONVERSATION_WINDOW since THEY last
  # wrote (not since the account last replied) — in which case a fresh
  # ticket is started instead. The contact stays the same either way, so
  # their prior conversation(s) remain visible via the Recent Timeline.
  STALE_CONVERSATION_WINDOW = 48.hours

  def conversation
    @conversation ||= find_active_conversation
  end

  def find_active_conversation
    last_conversation = conversations.last
    return nil if last_conversation.blank?
    return nil if stale_conversation?(last_conversation)

    last_conversation
  end

  def stale_conversation?(candidate_conversation)
    last_contact_message_at = candidate_conversation.messages.incoming.maximum(:created_at) || candidate_conversation.created_at
    last_contact_message_at < STALE_CONVERSATION_WINDOW.ago
  end

  def create_conversation
    ::Conversation.create!(conversation_params)
  end

  def inbox
    @inbox ||= ::Inbox.find_by(id: auth_token_params[:inbox_id])
  end

  def conversation_params
    # FIXME: typo referrer in additional attributes, will probably require a migration.
    {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: {
        browser_language: browser.accept_language&.first&.code,
        browser: browser_params,
        initiated_at: timestamp_params,
        referer: permitted_params[:message][:referer_url]
      },
      custom_attributes: permitted_params[:custom_attributes].presence || {}
    }
  end

  def contact_email
    permitted_params.dig(:contact, :email)&.downcase
  end

  def contact_name
    return if @contact.email.present? || @contact.phone_number.present? || @contact.identifier.present?

    permitted_params.dig(:contact, :name) || (contact_email.split('@')[0] if contact_email.present?)
  end

  def contact_phone_number
    permitted_params.dig(:contact, :phone_number)
  end

  def contact_custom_attributes
    permitted_params.dig(:contact, :custom_attributes)&.to_h
  end

  def browser_params
    {
      browser_name: browser.name,
      browser_version: browser.full_version,
      device_name: browser.device.name,
      platform_name: browser.platform.name,
      platform_version: browser.platform.version
    }
  end

  def timestamp_params
    { timestamp: permitted_params[:message][:timestamp] }
  end

  def message_params
    {
      account_id: conversation.account_id,
      sender: @contact,
      content: permitted_params[:message][:content],
      inbox_id: conversation.inbox_id,
      content_attributes: {
        in_reply_to: permitted_params[:message][:reply_to]
      },
      echo_id: permitted_params[:message][:echo_id],
      message_type: :incoming
    }
  end
end
