module GoogleMaps
  def self.geocode(location)
    body = Rails.cache.fetch("google_maps/geocode/#{location.parameterize}", expires_in: 1.day) do
      query = {
        address: location,
        key: ENV['GOOGLE_MAPS_API_KEY']
      }
      HTTParty.get("https://maps.googleapis.com/maps/api/geocode/json", query: query).body
    end
    response = JSON.parse(body, symbolize_names: true)

    unless response[:status] == 'OK'
      logger.error response[:status] unless response[:status] == 'OK'
      return
    end

    {
      formatted_address: response.dig(:results, 0, :formatted_address),
      lat: response.dig(:results, 0, :geometry, :location, :lat),
      long: response.dig(:results, 0, :geometry, :location, :lng)
    }
  end
end
