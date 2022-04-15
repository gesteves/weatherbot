module DarkSky
  def self.forecast(location:, lat:, long:, unit_system: 'auto')
    body = HTTParty.get("https://api.darksky.net/forecast/#{ENV['DARKSKY_API_KEY']}/#{lat},#{long}", query: query).body
    response = JSON.parse(body, symbolize_names: true)
    response[:location] = location
    response
  end
end
