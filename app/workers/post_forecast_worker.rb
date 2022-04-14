class PostForecastWorker < ApplicationWorker
  def perform(location, response_url)
    return if location.blank? || response_url.blank?

    geocoded = GoogleMaps.geocode(location)

    unless geocoded[:status] == 'OK'
      logger.error geocoded[:status]
      Slack.post_to_webhook(response_url: response_url, text: "Sorry, I don’t understand that location!", blocks: blocks, response_type: "ephemeral")
      return
    end

    lat = geocoded.dig(:results, 0, :geometry, :location, :lat)
    long = geocoded.dig(:results, 0, :geometry, :location, :lng)
    formatted_address = geocoded.dig(:results, 0, :formatted_address)

    forecast = DarkSky.forecast(location: formatted_address, lat: lat, long: long)
    blocks = ForecastPresenter.new(forecast).to_blocks
    text = "Weather forecast for #{forecast[:formatted_address]}: https://darksky.net/#{forecast[:lat]},#{forecast[:long]}"
    Slack.post_to_webhook(response_url: response_url, text: text, blocks: blocks, response_type: "in_channel")
  end
end
