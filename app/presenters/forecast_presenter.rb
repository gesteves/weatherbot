class ForecastPresenter < SimpleDelegator
  include ActionView::Helpers::NumberHelper
  def short_forecast_blocks
    blocks = []
    blocks << {
			type: "section",
			text: {
				type: "mrkdwn",
				text: "*Weather forecast for <https://darksky.net/#{dig(:latitude)},#{dig(:longitude)}|#{dig(:location)}>*"
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
    blocks.flatten.compact
  end

  def long_forecast_blocks
    blocks = []
    blocks << {
			type: "section",
			text: {
				type: "mrkdwn",
				text: "*Weather forecast for <https://darksky.net/#{dig(:latitude)},#{dig(:longitude)}|#{dig(:location)}>*"
			}
		}

    blocks << divider
    blocks << alerts_block
    blocks << currently_block
    blocks << divider
    blocks << minutely_block
    blocks << next_hour_chart
    blocks << divider
    blocks << hourly_block
    blocks << divider
    blocks << daily_block
    blocks.flatten.compact
  end

  private

  def divider
    {	type: "divider" }
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

    summary = "#{icon_to_emoji(currently.dig(:icon))} #{currently.dig(:summary).sub(/\.$/, '')}, #{currently.dig(:temperature).round}°#{temp_unit}"

    context = []
    context << "Feels like *#{currently.dig(:apparentTemperature).round}°#{temp_unit}*" if currently.dig(:temperature).round != currently.dig(:apparentTemperature).round
    context << "Humidity *#{number_to_percentage(currently.dig(:humidity) * 100, precision: 0)}*" if currently.dig(:humidity).present?
    context << "Dew point *#{currently.dig(:dewPoint).round}°#{temp_unit}*" if currently.dig(:dewPoint).present?
    context << "UV index *#{currently.dig(:uvIndex)}*" if currently.dig(:uvIndex).present?
    context << "Wind *#{wind_speed(currently.dig(:windSpeed))} #{wind_direction(currently.dig(:windBearing))}*" if currently.dig(:windSpeed).present? && currently.dig(:windBearing).present?
    context << "Gusts *#{wind_speed(currently.dig(:windGust))}*" if currently.dig(:windGust).present?

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Right now*\n#{summary.strip}"
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

    summary = "#{icon_to_emoji(minutely.dig(:icon))} #{minutely.dig(:summary)}"

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Next hour*\n#{summary.strip}"
        }
      }
    ]
  end

  def hourly_block
    hourly = dig(:hourly)
    return if hourly.blank?

    summary = "#{icon_to_emoji(hourly.dig(:icon))} #{hourly.dig(:summary)}"

    now = Time.now.to_i
    data = hourly.dig(:data)&.select { |d| d[:time] > now }

    max_temp = data&.max { |a,b| a[:apparentTemperature] <=> b[:apparentTemperature] }
    min_temp = data&.min { |a,b| a[:apparentTemperature] <=> b[:apparentTemperature] }

    context = []
    context << "Low *#{min_temp[:apparentTemperature].round}°#{temp_unit}*"
    context << "High *#{max_temp[:apparentTemperature].round}°#{temp_unit}*"

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Next 24 hours*\n#{summary.strip}"
        }
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: context.join(' | ')
          }
        ]
      }
    ]
  end

  def daily_block
    daily = dig(:daily)
    return if daily.blank?

    summary = "#{icon_to_emoji(daily.dig(:icon))} #{daily.dig(:summary)}"

    now = Time.now.to_i
    data = daily.dig(:data)&.select { |d| d[:time] > now }

    max_temp = data&.max { |a,b| a[:apparentTemperatureMax] <=> b[:apparentTemperatureMax] }
    min_temp = data&.min { |a,b| a[:apparentTemperatureMin] <=> b[:apparentTemperatureMin] }

    context = []
    context << "Low *#{min_temp[:apparentTemperatureMin].round}°#{temp_unit}* on <!date^#{min_temp[:apparentTemperatureMinTime]}^{date_long}|#{Time.at(min_temp[:apparentTemperatureMinTime]).strftime('%A, %B %-d')}>"
    context << "High *#{max_temp[:apparentTemperatureMax].round}°#{temp_unit}* on <!date^#{max_temp[:apparentTemperatureMaxTime]}^{date_long}|#{Time.at(max_temp[:apparentTemperatureMaxTime]).strftime('%A, %B %-d')}>"

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Next 7 days*\n#{summary.strip}"
        }
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: context.join(' | ')
          }
        ]
      }
    ]
  end

  def next_hour_chart
    minutely = dig(:minutely)
    return if minutely.blank?

    qc = QuickChart.new(
      {
        type: "line",
        data: {
          labels: minutely[:data].map { |d| Time.at(d[:time]).in_time_zone(dig(:timezone)).strftime('%l:%M') },
          datasets: [{
            label: "Chance of precipitation",
            fill: false,
            borderColor: 'blue',
            data: minutely[:data].map { |d| d[:precipProbability] * 100 },
            pointRadius: 0
          }]
        },
        options: {
          title: {
            display: true,
            text: 'Chance of precipitation',
          },
          legend: {
            display: false
          },
          scales: {
            xAxes: [
              {
                display: true,
                scaleLabel: {
                  display: false
                },
                gridLines: {
                  display: false
                },
                ticks: {
                  maxTicksLimit: 28,
                  callback: "(val) => { return val + '%'; }"
                }
              },
            ],
            yAxes: [
              {
                display: true,
                scaleLabel: {
                  display: false
                },
                ticks: {
                  beginAtZero: true,
                  suggestedMin: 0,
                  suggestedMax: 100
                }
              },
            ],
          },
        }
      },
      width: 600,
      height: 400,
      device_pixel_ratio: 2.0,
    )

    {
			"type": "image",
			"image_url": qc.get_url,
			"alt_text": "Chance of precipitation for the next hour"
		}
  end
end
