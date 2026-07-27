# Moves emails out of the Microsoft (Outlook/Office 365) mailbox INBOX into the
# mailbox's Deleted Items folder — a *soft* delete that stays recoverable in
# Outlook. Reuses the OAuth IMAP connection from the fetch service.
class Imap::MicrosoftDeleteEmailService < Imap::MicrosoftFetchEmailService
  DEFAULT_TRASH_FOLDER = 'Deleted Items'.freeze

  # @param message_ids [Array<String>] RFC 822 Message-IDs (stored as the
  #   message `source_id` on incoming email messages)
  # @return [Integer] number of mailbox messages moved to Deleted Items
  def move_to_deleted(message_ids)
    ids = Array(message_ids).compact_blank.uniq
    return 0 if ids.empty? || channel.provider_config['access_token'].blank?

    folder = trash_folder
    moved = 0
    ids.each do |message_id|
      uids = imap_client.uid_search(['HEADER', 'Message-ID', message_id])
      next if uids.blank?

      imap_client.uid_move(uids, folder)
      moved += uids.length
    end
    moved
  ensure
    terminate_imap_connection
  end

  private

  # Prefer the mailbox's SPECIAL-USE \Trash folder; fall back to the English
  # Office 365 default so a differently-localised mailbox still soft-deletes.
  def trash_folder
    special_use = imap_client.list('', '*').to_a.find { |box| box.attr.include?(:Trash) }
    special_use&.name || DEFAULT_TRASH_FOLDER
  end
end
