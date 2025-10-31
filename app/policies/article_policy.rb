class ArticlePolicy < ApplicationPolicy
  def index?
    @account.users.include?(@user)
  end

  def update?
    @account_user.administrator? || @account_user.manager?
  end

  def show?
    @account_user.administrator? || @account_user.manager?
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

  def reorder?
    @account_user.administrator? || @account_user.manager?
  end
end

ArticlePolicy.prepend_mod_with('ArticlePolicy')
