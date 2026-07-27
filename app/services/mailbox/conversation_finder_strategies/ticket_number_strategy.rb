class Mailbox::ConversationFinderStrategies::TicketNumberStrategy < Mailbox::ConversationFinderStrategies::BaseStrategy
  # Matches a Peach Labels ticket number in the subject, e.g. "[#2607261]" or
  # "#2607261". Ticket numbers are yymmdd + a daily counter, so they are always
  # 7+ digits — this avoids matching small display ids or unrelated order numbers.
  # This lets a customer's fresh email (or a reply that lost its threading
  # headers) merge into the right ticket as long as the number is in the subject.
  TICKET_PATTERN = /#\s?(\d{7,})/

  def initialize(mail)
    super(mail)
    @channel = EmailChannelFinder.new(mail).perform
  end

  def find
    return nil unless @channel

    match = TICKET_PATTERN.match(mail.subject.to_s)
    return nil unless match

    @channel.inbox.conversations.find_by("conversations.additional_attributes->>'ticket_number' = ?", match[1])
  end
end
