class ContactPolicy < ApplicationPolicy
  def index?
    true
  end

  def active?
    true
  end

  def import?
    @account_user.administrator? || @account_user.can?('contact_manage')
  end

  def export?
    @account_user.administrator? || @account_user.can?('contact_manage')
  end

  def search?
    true
  end

  def filter?
    true
  end

  def update?
    true
  end

  def contactable_inboxes?
    true
  end

  def destroy_custom_attributes?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def avatar?
    true
  end

  def destroy?
    @account_user.administrator? || @account_user.can?('contact_manage')
  end
end
