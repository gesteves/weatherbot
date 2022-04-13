class PostForecastWorker < ApplicationWorker
  def perform(location, team_id, channel_id)
    return if location.blank? || team_id.blank? || channel_id.blank?
    team = Team.find_by(slack_id: team_id)
    return if team.blank?

    forecast = DarkSky.forecast(location)
    blocks = ForecastPresenter.new(forecast).to_blocks
    text = "Weather forecast for #{forecast[:formatted_address]}: https://darksky.net/#{forecast[:lat]},#{forecast[:long]}"
    team.post_message(channel_id: channel_id, text: text, blocks: blocks)
  end
end
