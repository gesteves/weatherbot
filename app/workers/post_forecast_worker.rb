class PostForecastWorker < ApplicationWorker
  def perform(location, response_url)
    return if location.blank? || response_url.blank?

    geocoded = GoogleMaps.geocode(location)

    unless geocoded[:status] == 'OK'
      logger.error geocoded[:status]
      Slack.post_to_webhook(response_url: response_url, text: "Sorry, I don’t understand that location!", response_type: "in_channel")
      return
    end

    lat = geocoded.dig(:results, 0, :geometry, :location, :lat)
    long = geocoded.dig(:results, 0, :geometry, :location, :lng)
    formatted_address = geocoded.dig(:results, 0, :formatted_address)

    text = "Weather forecast for #{formatted_address}: https://darksky.net/#{lat},#{long}"
    blocks = Rails.cache.fetch("/slash/forecast/#{lat}/#{long}", expires_in: 1.minute) do
      forecast = DarkSky.forecast(location: formatted_address, lat: lat, long: long)
      ForecastPresenter.new(forecast).short_forecast_blocks
    end
    Slack.post_to_webhook(response_url: response_url, text: text, blocks: blocks, response_type: "in_channel")
  end
end
