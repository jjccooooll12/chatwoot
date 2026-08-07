module UserAttributeHelpers
  extend ActiveSupport::Concern

  # Staff are always shown as "First L." — "Libero Cole" renders as
  # "Libero C." on every surface (dashboard, notification mail, reply
  # headers), never with a full last name. A single-word name is already in
  # that shape and passes through untouched. Derived from `name` rather than
  # `display_name` so the rule can't be defeated by a user setting a display
  # name; `display_name`/email only stand in when `name` is somehow blank.
  # Mirrored on the frontend by shared/helpers/agentNameHelper#shortenAgentName.
  def available_name
    parts = name.to_s.strip.split(/\s+/)

    return self[:display_name].presence || email.to_s.split('@').first if parts.empty?
    return parts.first if parts.one?

    "#{parts.first} #{parts.last[0].upcase}."
  end

  def availability_status
    current_account_user&.availability_status
  end

  def auto_offline
    current_account_user&.auto_offline
  end

  def inviter
    current_account_user&.inviter
  end

  def active_account_user
    account_users.order(Arel.sql('active_at DESC NULLS LAST'))&.first
  end

  def current_account_user
    # We want to avoid subsequent queries in case where the association is preloaded.
    # using where here will trigger n+1 queries.
    account_users.find { |ac_usr| ac_usr.account_id == Current.account.id } if Current.account
  end

  def account
    current_account_user&.account
  end

  def administrator?
    current_account_user&.administrator?
  end

  def agent?
    current_account_user&.agent?
  end

  def role
    current_account_user&.role
  end

  # Used internally for Chatwoot in Chatwoot
  def hmac_identifier
    hmac_key = GlobalConfig.get('CHATWOOT_INBOX_HMAC_KEY')['CHATWOOT_INBOX_HMAC_KEY']
    return OpenSSL::HMAC.hexdigest('sha256', hmac_key, email) if hmac_key.present?

    ''
  end
end
