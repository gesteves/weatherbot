module GoogleMaps
  def self.geocode(location)
    body = Rails.cache.fetch("google_maps/geocode/#{location.parameterize}", expires_in: 1.day) do
      query = {
        address: location,
        key: ENV['GOOGLE_MAPS_API_KEY']
      }
      HTTParty.get("https://maps.googleapis.com/maps/api/geocode/json", query: query).body
    end
    JSON.parse(body, symbolize_names: true)
  end
end
