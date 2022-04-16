class HomeController < ApplicationController
  before_action :set_max_age

  def index
    @teams_count = Team.all.count
    @users_count = User.all.count
    @noindex = false
    @title = "Weatherbot"
  end

  def success
    @noindex = true
    @title = "Weatherbot • Success!"
  end

  def privacy
    @title = "Weatherbot • Privacy"
  end
end
