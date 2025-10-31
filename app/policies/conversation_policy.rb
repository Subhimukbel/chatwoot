class ConversationPolicy < ApplicationPolicy
  def index?
    true
  end

  def destroy?
    @account_user&.administrator? || @account_user&.can?('conversation_manage')
  end
end
