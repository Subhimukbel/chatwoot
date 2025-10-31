class PortalPolicy < ApplicationPolicy
  def index?
    @account.users.include?(@user)
  end

  def update?
    @account_user.administrator? || @account_user.manager?
  end

  def show?
    @account.users.include?(@user)
  end

  def edit?
    @account_user.administrator? || @account_user.manager?
  end

  def create?
    @account_user.administrator? || @account_user.manager?
  end

  def destroy?
    @account_user.administrator? || @account_user.manager?
  end

  def logo?
    @account_user.administrator? || @account_user.manager?
  end

  def send_instructions?
    @account_user.administrator? || @account_user.manager?
  end

  def ssl_status?
    @account.users.include?(@user)
  end
end

PortalPolicy.prepend_mod_with('PortalPolicy')
