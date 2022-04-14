module DarkSky
  def self.forecast(location:, lat:, long:, unit_system: 'auto')
    body = Rails.cache.fetch("darksky/forecast/#{lat}/#{long}/#{unit_system}", expires_in: 10.minutes) do
      query = {
        units: unit_system
      }
      HTTParty.get("https://api.darksky.net/forecast/#{ENV['DARKSKY_API_KEY']}/#{lat},#{long}", query: query).body
    end

    response = JSON.parse(body, symbolize_names: true)
    response[:location] = location
    response
  end
end
