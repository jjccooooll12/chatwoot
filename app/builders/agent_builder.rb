# The AgentBuilder class is responsible for creating a new agent.
# It initializes with necessary attributes and provides a perform method
# to create a user and account user in a transaction.
class AgentBuilder
  LIMIT_EXCEEDED_MESSAGE = 'Account limit exceeded. Please purchase more licenses'.freeze

  class LimitExceededError < StandardError
    def initialize
      super(AgentBuilder::LIMIT_EXCEEDED_MESSAGE)
    end
  end

  class InvalidAgentError < StandardError; end

  # Domain used for the synthetic (login-only) address minted for agents created
  # without an email. These addresses are never used to send or receive mail.
  LOGIN_AGENT_EMAIL_DOMAIN = 'agents.peach-labels.com'.freeze

  # Initializes an AgentBuilder with necessary attributes.
  # @param email [String] the email of the user.
  # @param name [String] the name of the user.
  # @param role [String] the role of the user, defaults to 'agent' if not provided.
  # @param inviter [User] the user who is inviting the agent (Current.user in most cases).
  # @param availability [String] the availability status of the user, defaults to 'offline' if not provided.
  # @param auto_offline [Boolean] the auto offline status of the user.
  pattr_initialize [:email, { name: '' }, { password: nil }, :inviter, :account, { role: :agent }, { availability: :offline }, { auto_offline: false }]

  # Creates a user and account user in a transaction.
  # @return [User] the created user.
  def perform
    account.with_lock do
      raise LimitExceededError unless can_add_agent?

      ActiveRecord::Base.transaction do
        @user = find_or_create_user
        create_account_user
      end
    end
    @user
  end

  private

  def can_add_agent?
    account.usage_limits[:agents] > account.account_users.count
  end

  # Finds a user by email or creates a new one with a temporary password.
  # @return [User] the found or created user.
  def find_or_create_user
    return create_login_user if email.blank?

    user = User.from_email(email)
    return user if user

    @name = email.split('@').first if @name.blank?
    temp_password = "1!aA#{SecureRandom.alphanumeric(12)}"
    User.create!(email: email, name: @name, password: temp_password, password_confirmation: temp_password)
  end

  # Creates an agent that signs in with their name (as a username) plus a password
  # set by the admin, with no real email. A synthetic address is minted only to
  # satisfy the unique/login constraints; the agent never uses it to send/receive.
  def create_login_user
    raise InvalidAgentError, I18n.t('errors.messages.blank') if @name.blank?
    raise InvalidAgentError, 'An agent with this name already exists' if User.find_by_login_name(@name)

    user = User.new(email: synthetic_login_email, name: @name, password: password, password_confirmation: password)
    user.skip_confirmation!
    user.save!
    user
  end

  def synthetic_login_email
    slug = @name.parameterize.presence || 'agent'
    candidate = "#{slug}@#{LOGIN_AGENT_EMAIL_DOMAIN}"
    candidate = "#{slug}-#{SecureRandom.hex(3)}@#{LOGIN_AGENT_EMAIL_DOMAIN}" while User.exists?(email: candidate)
    candidate
  end

  # Checks if the user needs confirmation.
  # @return [Boolean] true if the user is persisted and not confirmed, false otherwise.
  def user_needs_confirmation?
    @user.persisted? && !@user.confirmed?
  end

  # Creates an account user linking the user to the current account.
  def create_account_user
    AccountUser.create!({
      account_id: account.id,
      user_id: @user.id,
      inviter_id: inviter.id
    }.merge({
      role: role,
      availability: availability,
      auto_offline: auto_offline
    }.compact))
  end
end

AgentBuilder.prepend_mod_with('AgentBuilder')
