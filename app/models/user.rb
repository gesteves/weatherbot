class User < ApplicationRecord
  belongs_to :team

  validates :slack_id, presence: true

  def avatar
    return if Rails.env.test?
    Rails.cache.fetch("slack/user/avatar/#{id}-#{slack_id}", expires_in: 1.day) do
      slack = Slack.new
      response = slack.user_info(access_token: team.access_token, user_id: slack_id)
      return if response.blank?
      raise response[:error] unless response[:ok]
      response.dig(:user, :profile, :image_192).presence || response.dig(:user, :profile, :image_72).presence || response.dig(:user, :profile, :image_48).presence || response.dig(:user, :profile, :image_32).presence || response.dig(:user, :profile, :image_24).presence || response.dig(:user, :profile, :image_original).presence
    end
  end

  def real_name
    return if Rails.env.test?
    Rails.cache.fetch("slack/user/real_name/#{id}-#{slack_id}", expires_in: 1.day) do
      slack = Slack.new
      response = slack.user_info(access_token: team.access_token, user_id: slack_id)
      return if response.blank?
      raise response[:error] unless response[:ok]
      response.dig(:user, :real_name).presence
    end
  end

  def first_name
    return if Rails.env.test?
    Rails.cache.fetch("slack/user/first_name/#{id}-#{slack_id}", expires_in: 1.day) do
      slack = Slack.new
      response = slack.user_info(access_token: team.access_token, user_id: slack_id)
      return if response.blank?
      raise response[:error] unless response[:ok]
      response.dig(:user, :profile, :first_name).presence
    end
  end

  def username
    return if Rails.env.test?
    Rails.cache.fetch("slack/user/username/#{id}-#{slack_id}", expires_in: 1.day) do
      slack = Slack.new
      response = slack.user_info(access_token: team.access_token, user_id: slack_id)
      return if response.blank?
      raise response[:error] unless response[:ok]
      response.dig(:user, :name).presence
    end
  end

  def display_name
    return if Rails.env.test?
    first_name || real_name || username
  end

  def mention
    "<@#{slack_id}>"
  end

  def update_app_home
    team.update_app_home(user_id: slack_id, view: HomeViewPresenter.new(self).to_view)
  end

  def open_preferences(trigger_id)
    team.open_view(trigger_id: trigger_id, view: PreferencesPresenter.new(self).to_view)
  end
end
