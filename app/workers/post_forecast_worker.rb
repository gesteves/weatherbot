class PostForecastWorker < ApplicationWorker
  def perform(location, response_url)
    return if location.blank? || response_url.blank?

    forecast = DarkSky.forecast(location)
    blocks = ForecastPresenter.new(forecast).to_blocks
    text = "Weather forecast for #{forecast[:formatted_address]}: https://darksky.net/#{forecast[:lat]},#{forecast[:long]}"
    Slack.post_to_webhook(response_url: response_url, text: text, blocks: blocks)
  end
end
