class Conversations::AutoFollowUpService
  # How long a pending, auto-follow-up conversation keeps waiting on the customer
  # before it is handed back to a human (Pending -> Open). Keyed by priority.
  REOPEN_WINDOWS = {
    'low' => 5.days,
    'medium' => 3.days,
    'high' => 48.hours,
    'urgent' => 24.hours
  }.freeze

  # Human-readable form of the windows above, used in the reopen audit note.
  WINDOW_LABELS = {
    'low' => '5 days',
    'medium' => '3 days',
    'high' => '48 hours',
    'urgent' => '24 hours'
  }.freeze

  NUDGE_INTERVAL = 24.hours

  pattr_initialize [:conversation!]

  def perform
    return unless eligible?
    return unless waiting_on_customer?

    if Time.current >= reopen_at
      reopen_for_human
    elsif due_for_nudge?
      send_nudge
    end
  end

  private

  def eligible?
    conversation.pending? && conversation.custom_attributes['freshdesk_auto_follow_up'] == 'yes'
  end

  def priority
    conversation.priority.presence || 'low'
  end

  def window
    REOPEN_WINDOWS[priority]
  end

  # The last genuine agent reply (excludes our own automated nudges so they don't
  # keep resetting the waiting clock).
  def last_agent_reply
    @last_agent_reply ||= conversation.messages
                                      .where(message_type: :outgoing, private: false)
                                      .where("messages.additional_attributes->>'auto_follow_up_nudge' IS NULL")
                                      .order(created_at: :desc)
                                      .first
  end

  def last_customer_message_at
    conversation.messages.incoming.maximum(:created_at)
  end

  def last_nudge_at
    conversation.messages
                .where(message_type: :outgoing)
                .where("messages.additional_attributes->>'auto_follow_up_nudge' = 'true'")
                .maximum(:created_at)
  end

  # We only chase the customer when our last genuine reply is still the most recent
  # message in the thread. Once the customer replies, the ball is back in our court
  # and the follow-up stops.
  def waiting_on_customer?
    return false if last_agent_reply.nil?

    customer_at = last_customer_message_at
    customer_at.nil? || customer_at < last_agent_reply.created_at
  end

  def reopen_at
    last_agent_reply.created_at + window
  end

  # Nudge cadence resets whenever we send a new genuine reply, so the baseline is
  # the later of "our last reply" and "our last nudge".
  def due_for_nudge?
    baseline = [last_nudge_at, last_agent_reply.created_at].compact.max
    Time.current - baseline >= NUDGE_INTERVAL
  end

  def send_nudge
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: nudge_body,
      additional_attributes: { 'auto_follow_up_nudge' => true }
    )
  end

  def reopen_for_human
    conversation.open!
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      private: true,
      content: "Auto follow-up: reopened after no customer response within #{WINDOW_LABELS[priority]}."
    )
  end

  def contact_first_name
    conversation.contact.name.to_s.split.first.presence || 'there'
  end

  def ticket_subject
    subject = conversation.additional_attributes['mail_subject'].presence || 'your recent request'
    subject.sub(/\A\s*re:\s*/i, '')
  end

  def nudge_body
    <<~BODY.strip
      Hi #{contact_first_name},

      This is a friendly reminder about your ticket ##{conversation.ticket_number} — "#{ticket_subject}". We're still waiting to hear back from you before we can move forward.

      [Reply to this ticket](#{reply_mailto_url})

      If everything's already sorted on your end, just let us know and we'll close it out.

      Warm regards,
      Peach Labels
    BODY
  end

  # A mailto link that opens the customer's mail app pre-addressed to support with
  # the ticket number in the subject (so their reply merges back into this ticket)
  # and the previous conversation quoted, so they can see what we're asking.
  def reply_mailto_url
    subject = "Re: Peach Labels - Ticket [##{conversation.ticket_number}] #{ticket_subject}".strip
    "mailto:#{support_email}?subject=#{ERB::Util.url_encode(subject)}&body=#{ERB::Util.url_encode(reply_quoted_context)}"
  end

  def support_email
    conversation.inbox.channel.try(:email).presence || conversation.account.support_email
  end

  # The customer writes at the top (the leading blank lines put their cursor
  # there); the full ticket history is quoted below, newest first, so they can
  # see everything they're replying to.
  def reply_quoted_context
    history = conversation_history.map { |message| quote_message(message) }.join("\n\n")
    return "\n\n" if history.blank?

    "\n\n----\n#{history}\n"
  end

  def conversation_history
    conversation.messages
                .where(message_type: [:incoming, :outgoing], private: false)
                .where("messages.additional_attributes->>'auto_follow_up_nudge' IS NULL")
                .reorder(created_at: :desc)
  end

  def quote_message(message)
    sender = message.incoming? ? (conversation.contact.name.presence || 'You') : 'Peach Labels'
    quoted = message.content.to_s.split("\n").map { |line| "> #{line}" }.join("\n")
    "On #{message.created_at.strftime('%b %-d, %Y')}, #{sender} wrote:\n#{quoted}"
  end
end
