class ForecastPresenter < SimpleDelegator
  include ActionView::Helpers::NumberHelper
  def to_blocks
    blocks = []
    blocks << {
			type: "section",
			text: {
				type: "mrkdwn",
				text: "*Weather forecast for <https://darksky.net/#{dig(:latitude)},#{dig(:longitude)}|#{dig(:formatted_address)}>*"
			}
		}

    blocks << {
			type: "divider"
		}

    blocks << alerts_block
    blocks << currently_block
    blocks << minutely_block
    blocks << hourly_block
    blocks << daily_block

    blocks << {
			type: "divider"
		}
		blocks << {
			type: "context",
			elements: [
				{
					type: "mrkdwn",
					text: "<https://darksky.net/poweredby/|Powered by Dark Sky>"
				}
			]
		}
    blocks.compact
  end

  private

  def temp_unit
    dig(:flags, :units) == 'us' ? 'F' : 'C'
  end

  def alerts_block
    return if dig(:alerts).nil?
    {
			type: "section",
			text: {
				type: "mrkdwn",
				text: dig(:alerts).map { |alert| ":warning: <#{alert[:uri]}|#{alert[:title]}>" }.join("\n")
			}
		}
  end

  def currently_block
    currently = dig(:currently)
    return if currently.blank?

    temperature = if currently.dig(:temperature).round == currently.dig(:apparentTemperature).round
      "#{currently.dig(:temperature).round}°#{temp_unit}"
    else
      "#{currently.dig(:temperature).round}°#{temp_unit} (feels like #{currently.dig(:apparentTemperature).round}°#{temp_unit})"
    end

    text = "#{icon_to_emoji(currently.dig(:icon))} #{currently.dig(:summary)}, #{temperature}, #{number_to_percentage(currently.dig(:humidity) * 100, precision: 0)} humidity, dew point #{currently.dig(:dewPoint).round}°#{temp_unit}".strip

    {
			type: "section",
			text: {
				type: "mrkdwn",
				text: "*Right now*\n#{text}"
			}
		}
  end

  def minutely_block
    minutely = dig(:minutely)
    return if minutely.blank?

    text = "#{icon_to_emoji(minutely.dig(:icon))} #{minutely.dig(:summary)}".strip

    {
			type: "section",
			text: {
				type: "mrkdwn",
				text: "*Next hour*\n#{text}"
			}
		}
  end

  def hourly_block
    hourly = dig(:hourly)
    return if hourly.blank?

    apparent_temperatures = hourly.dig(:data)&.slice(0, 24)&.map { |d| d[:apparentTemperature]}
    high = apparent_temperatures.max.round
    low = apparent_temperatures.min.round
    text = "#{icon_to_emoji(hourly.dig(:icon))} #{hourly.dig(:summary).sub(/\.$/, '')}. The high for the next 24 hours is #{high}°#{temp_unit}, and the low is #{low}°#{temp_unit}.".strip

    {
			type: "section",
			text: {
				type: "mrkdwn",
				text: "*Next 24 hours*\n#{text}"
			}
		}
  end

  def daily_block
    daily = dig(:daily)
    return if daily.blank?

    text = "#{icon_to_emoji(daily.dig(:icon))} #{daily.dig(:summary)}".strip

    {
			type: "section",
			text: {
				type: "mrkdwn",
				text: "*Next 7 days*\n#{text}"
			}
		}
  end

  def icon_to_emoji(icon)
    mapping = {
      'clear-day': ':sunny:',
      'clear-night': ':moon:',
      'rain': ':rain_cloud:',
      'snow': ':snowflake:',
      'sleet': ':snow_cloud:',
      'wind': ':dash:',
      'fog': ':fog:',
      'cloudy': ':cloud:',
      'partly-cloudy-day': ':partly_sunny:',
      'partly-cloudy-night': ':cloud:',
      'thunderstorm': ':lightning:',
      'tornado': ':tornado:'
    }.with_indifferent_access
    mapping[icon] || ''
  end
end
