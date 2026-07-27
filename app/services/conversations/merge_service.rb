# frozen_string_literal: true

require 'erb'

class Conversations::MergeService
  pattr_initialize [:account!, :primary_conversation!, :secondary_conversation!, :user]

  def perform
    return primary_conversation if primary_conversation.id == secondary_conversation.id

    ActiveRecord::Base.transaction do
      validate_conversations!
      primary_conversation.reload.lock!
      secondary_conversation.reload.lock!

      update_merge_metadata!
      close_secondary_conversation!
      create_primary_merge_activity!
      create_secondary_merge_activity!
    end

    primary_conversation
  end

  private

  def validate_conversations!
    return if primary_conversation.account_id == account.id && secondary_conversation.account_id == account.id

    raise ActiveRecord::RecordNotFound
  end

  def update_merge_metadata!
    primary_conversation.update!(
      additional_attributes: primary_conversation.additional_attributes.merge(
        'merged_ticket_numbers' => merged_ticket_numbers
      )
    )

    secondary_conversation.update!(
      additional_attributes: secondary_conversation.additional_attributes.merge(
        'merged_into_ticket_number' => primary_conversation.ticket_number,
        'merged_into_display_id' => primary_conversation.display_id,
        'merged_at' => Time.current.iso8601
      )
    )
  end

  def close_secondary_conversation!
    secondary_conversation.resolved! unless secondary_conversation.resolved?
  end

  def merged_ticket_numbers
    existing = primary_conversation.additional_attributes['merged_ticket_numbers']
    Array(existing).map(&:to_s).push(secondary_conversation.ticket_number.to_s).uniq
  end

  def create_primary_merge_activity!
    create_merge_activity!(
      primary_conversation,
      I18n.t(
        'conversations.activity.merge.primary',
        secondary_ticket_link: ticket_link(secondary_conversation),
        primary_ticket: "##{primary_conversation.ticket_number}"
      ),
      role: 'primary',
      linked_conversation: secondary_conversation
    )
  end

  def create_secondary_merge_activity!
    create_merge_activity!(
      secondary_conversation,
      I18n.t(
        'conversations.activity.merge.secondary',
        secondary_ticket: "##{secondary_conversation.ticket_number}",
        primary_ticket_link: ticket_link(primary_conversation)
      ),
      role: 'secondary',
      linked_conversation: primary_conversation
    )
  end

  def create_merge_activity!(conversation, content, role:, linked_conversation:)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: content,
      content_attributes: {
        activity: {
          type: 'conversation_merged',
          role: role,
          linked_display_id: linked_conversation.display_id,
          linked_ticket_number: linked_conversation.ticket_number,
          performed_by: user&.name
        }.compact
      }
    )
  end

  def ticket_link(conversation)
    ticket = ERB::Util.html_escape("##{conversation.ticket_number}")
    href = ERB::Util.html_escape(
      "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
    )
    "<a href=\"#{href}\">#{ticket}</a>"
  end
end
