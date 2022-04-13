module DarkSky
  def self.forecast(location)
    unit_system = if location.match(/\s+in\s+(celsius|c|metric|si)$/i)
      location.sub!(/\s+in\s+(celsius|c|metric|si)$/i, '')
      'si'
    elsif location.match(/\s+in\s+(fahrenheit|f|imperial)$/i)
      location.sub!(/\s+in\s+(fahrenheit|f|imperial)$/i, '')
      'us'
    else
      'auto'
    end

    geocoded = GoogleMaps.geocode(location)
    lat = geocoded[:lat]
    long = geocoded[:long]

    body = Rails.cache.fetch("darksky/forecast/#{lat}/#{long}", expires_in: 10.minutes) do
      query = {
        units: unit_system
      }
      HTTParty.get("https://api.darksky.net/forecast/#{ENV['DARKSKY_API_KEY']}/#{lat},#{long}", query: query).body
    end

    response = JSON.parse(body, symbolize_names: true)
    response[:formatted_address] = geocoded[:formatted_address]
    response
  end
end
