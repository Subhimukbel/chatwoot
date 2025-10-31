class UserPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.administrator? || @account_user.can?('team_manage')
  end

  def update?
    @account_user.administrator? || @account_user.can?('team_manage')
  end

  def destroy?
    @account_user.administrator? || @account_user.can?('team_manage')
  end

  def bulk_create?
    @account_user.administrator? || @account_user.can?('team_manage')
  end
end
