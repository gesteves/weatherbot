class PostForecastWorker < ApplicationWorker
  def perform(location, response_url)
    return if location.blank? || response_url.blank?

    geocoded = GoogleMaps.geocode(location)

    if geocoded.blank?
      Slack.post_to_webhook(response_url: response_url, text: "Sorry, I don’t understand that location!", blocks: blocks, response_type: "ephemeral")
      return
    end

    lat = geocoded[:lat]
    long = geocoded[:long]
    location = geocoded[:formatted_address]

    forecast = DarkSky.forecast(location: location, lat: lat, long: long)
    blocks = ForecastPresenter.new(forecast).to_blocks
    text = "Weather forecast for #{forecast[:formatted_address]}: https://darksky.net/#{forecast[:lat]},#{forecast[:long]}"
    Slack.post_to_webhook(response_url: response_url, text: text, blocks: blocks, response_type: "in_channel")
  end
end
