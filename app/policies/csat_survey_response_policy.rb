class CsatSurveyResponsePolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.can?('report_view')
  end

  def metrics?
    @account_user.administrator? || @account_user.can?('report_view')
  end

  def download?
    @account_user.administrator? || @account_user.can?('report_view')
  end
end

CsatSurveyResponsePolicy.prepend_mod_with('CsatSurveyResponsePolicy')
