class HookPolicy < ApplicationPolicy
  def create?
    @account_user.administrator? || @account_user.manager?
  end

  def update?
    @account_user.administrator? || @account_user.manager?
  end

  def process_event?
    true
  end

  def destroy?
    @account_user.administrator? || @account_user.manager?
  end
end
