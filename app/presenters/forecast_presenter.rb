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
					text: "Powered by <https://darksky.net/poweredby/|Dark Sky>"
				}
			]
		}
    blocks.flatten.compact
  end

  private

  def temp_unit
    dig(:flags, :units) == 'us' ? 'F' : 'C'
  end

  def wind_speed(speed)
    unit_system = dig(:flags, :units)
    units = {
      'ca': "km/h",
      'uk2': 'mph',
      'us': 'mph',
      'si': 'm/s'
    }.with_indifferent_access
    unit = units[unit_system]
    "#{speed.round} #{unit}"
  end

  def wind_direction(bearing)
    # https://stackoverflow.com/a/7490772
    value = (bearing/22.5) + 0.5
    directions = ["N","NNE","NE","ENE","E","ESE", "SE", "SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
    directions[(value % 16)]
  end

  def alerts_block
    return if dig(:alerts).nil?

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: dig(:alerts).map { |alert| ":warning: <#{alert[:uri]}|#{alert[:title]}>" }.join("\n")
        }
		  }
    ]
  end

  def currently_block
    currently = dig(:currently)
    return if currently.blank?

    summary = "#{currently.dig(:summary).sub(/\.$/, '')}, #{currently.dig(:temperature).round}°#{temp_unit}"

    context = []
    context << "Feels like *#{currently.dig(:apparentTemperature).round}°#{temp_unit}*" if currently.dig(:temperature).round != currently.dig(:apparentTemperature).round
    context << "Humidity *#{number_to_percentage(currently.dig(:humidity) * 100, precision: 0)}*" if currently.dig(:humidity).present?
    context << "Dew point *#{currently.dig(:dewPoint).round}°#{temp_unit}*" if currently.dig(:dewPoint).present?
    context << "UV index *#{currently.dig(:uvIndex)}*" if currently.dig(:uvIndex).present?
    context << "Wind *#{wind_speed(currently.dig(:windSpeed))} #{wind_direction(currently.dig(:windBearing))}*" if currently.dig(:windSpeed).present? && currently.dig(:windBearing).present?

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Right now*\n#{summary}"
        }
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: context.join(" | ")
          }
        ]
      }
    ]
  end

  def minutely_block
    minutely = dig(:minutely)
    return if minutely.blank?

    summary = minutely.dig(:summary)

    max_precipitation = minutely.dig(:data)&.max { |a,b| a[:precipProbability] <=> b[:precipProbability] }
    chance = number_to_percentage(max_precipitation[:precipProbability] * 100, precision: 0)
    chance = "#{chance} at <!date^#{max_precipitation[:time]}^{time}|#{Time.at(max_precipitation[:time]).strftime('%r')}>" if max_precipitation[:precipProbability] > 0
    context = "Chance of precipitation *#{chance}*"

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Next hour*\n#{summary}"
        }
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: context
          }
        ]
      }
    ]
  end

  def hourly_block
    hourly = dig(:hourly)
    return if hourly.blank?

    summary = hourly.dig(:summary)

    temps = hourly.dig(:data)&.slice(0, 24)&.map { |d| d[:apparentTemperature] }
    high = temps.max.round
    low = temps.min.round
    context = "Low *#{low}°#{temp_unit}* | High *#{high}°#{temp_unit}*"

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Next 24 hours*\n#{summary}"
        }
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: context
          }
        ]
      }
    ]
  end

  def daily_block
    daily = dig(:daily)
    return if daily.blank?

    text = daily.dig(:summary)

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Next 7 days*\n#{text}"
        }
      }
    ]
  end
end
