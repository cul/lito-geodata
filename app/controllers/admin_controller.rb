
class AdminController < ApplicationController
  require 'geoblacklight/version'
  before_action :authenticate_user!
  layout false

  # /admin/system diagnostic page
  def system
    redirect_to root_path unless current_user.admin?
  end

end

