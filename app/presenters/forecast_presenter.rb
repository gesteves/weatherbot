class ForecastPresenter < SimpleDelegator
  include ActionView::Helpers::NumberHelper
  def short_forecast_blocks
    blocks = []
    blocks << header_block
    blocks << divider
    blocks << alerts_block
    blocks << currently_block
    blocks << minutely_block
    blocks << hourly_block
    blocks << daily_block
    blocks << divider
    blocks.flatten.compact
  end

  def long_forecast_blocks
    blocks = []
    blocks << header_block
    blocks << timestamp_block
    blocks << divider
    blocks << alerts_block
    blocks << currently_block
    blocks << divider
    blocks << minutely_block
    blocks << precipitation_line_chart(data: dig(:minutely, :data), time_format: '%l:%M %P', ticks: 28)
    blocks << divider
    blocks << hourly_block
    blocks << precipitation_temperature_line_chart(data: dig(:hourly, :data)&.select { |d| d[:time] > Time.now.to_i }&.slice(0, 24), time_format: '%l %P')
    blocks << divider
    blocks << daily_block
    blocks << precipitation_temperature_bar_chart(data: dig(:daily, :data)&.select { |d| d[:time] > Time.now.to_i }&.slice(0, 7), time_format: '%A')
    blocks << divider
    blocks.flatten.compact
  end

  private

  def divider
    {	type: "divider" }
  end

  def icon_to_emoji(icon)
    mapping = {
      'clear-day': ':sunny:',
      'clear-night': moon_phase_emoji,
      'rain': ':rain_cloud:',
      'snow': ':snowflake:',
      'sleet': ':snow_cloud:',
      'wind': ':dash:',
      'fog': ':fog:',
      'cloudy': ':cloud:',
      'partly-cloudy-day': ':partly_sunny:',
      'partly-cloudy-night': ':cloud:',
      'thunderstorm': ':thunder_cloud_and_rain:',
      'tornado': ':tornado:'
    }.with_indifferent_access
    mapping[icon] || ''
  end

  def moon_phase_emoji
    moon = dig(:daily, :data, 0, :moonPhase)
    return ":moon:" if moon.blank?
    if moon == 0
      ":new_moon:"
    elsif moon > 0 && moon < 0.25
      ":waxing_crescent_moon:"
    elsif moon == 0.25
      ":first_quarter_moon:"
    elsif moon > 0.25 && moon < 0.5
      ":waxing_gibbous_moon:"
    elsif moon == 0.5
      ":full_moon:"
    elsif moon > 0.5 && moon < 0.75
      ":waning_gibbous_moon:"
    elsif moon == 0.75
      ":last_quarter_moon:"
    elsif moon > 0.75
      ":waning_crescent_moon:"
    end
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

  def header_block
    {
			type: "section",
			text: {
				type: "mrkdwn",
				text: "*Weather forecast for <https://darksky.net/#{dig(:latitude)},#{dig(:longitude)}|#{dig(:location)}>*"
			}
		}
  end

  def alerts_block
    return if dig(:alerts).nil?

    dig(:alerts).map { |alert| alert_block(alert) }.flatten
  end

  def alert_block(alert)
    blocks = [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: ":warning: <#{alert[:uri]}|#{alert[:title]}>"
        }
      }
    ]

    if alert[:regions].present?
      blocks << {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: alert[:regions].join(', ')
          }
        ]
      }
    end

   blocks
  end

  def currently_block
    currently = dig(:currently)
    return if currently.blank?

    summary = "#{icon_to_emoji(currently.dig(:icon))} #{currently.dig(:summary).sub(/\.$/, '')}."

    context = []
    context << "*#{currently.dig(:temperature).round}°#{temp_unit}*"
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

    current_hour = Time.now.beginning_of_hour.to_i
    data = dig(:hourly, :data)&.find { |d| d[:time] >= current_hour }

    context = []
    context << "*#{data.dig(:temperature).round}°#{temp_unit}*"
    context << "Feels like *#{data.dig(:apparentTemperature).round}°#{temp_unit}*" if data.dig(:temperature).round != data.dig(:apparentTemperature).round
    context << "Humidity *#{number_to_percentage(data.dig(:humidity) * 100, precision: 0)}*" if data.dig(:humidity).present?
    context << "Dew point *#{data.dig(:dewPoint).round}°#{temp_unit}*" if data.dig(:dewPoint).present?
    context << "UV index *#{data.dig(:uvIndex)}*" if data.dig(:uvIndex).present?
    context << "Wind *#{wind_speed(data.dig(:windSpeed))} #{wind_direction(data.dig(:windBearing))}*" if data.dig(:windSpeed).present? && data.dig(:windBearing).present?
    context << "Gusts *#{wind_speed(data.dig(:windGust))}*" if data.dig(:windGust).present?

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Next hour*\n#{summary.strip}"
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

  def hourly_block
    hourly = dig(:hourly)
    return if hourly.blank?

    summary = "#{icon_to_emoji(hourly.dig(:icon))} #{hourly.dig(:summary)}"

    current_hour = Time.now.beginning_of_hour.to_i
    now = Time.now.to_i

    data = hourly.dig(:data)&.select { |d| d[:time] >= current_hour }&.slice(0, 24)
    max_temp = data&.max { |a,b| a[:apparentTemperature] <=> b[:apparentTemperature] }
    min_temp = data&.min { |a,b| a[:apparentTemperature] <=> b[:apparentTemperature] }

    sunrise = dig(:daily, :data)&.find { |d| d[:sunriseTime] > now }&.dig(:sunriseTime)
    sunset = dig(:daily, :data)&.find { |d| d[:sunsetTime] > now }&.dig(:sunsetTime)

    context = []
    context << "Low *#{min_temp[:apparentTemperature].round}°#{temp_unit}*"
    context << "High *#{max_temp[:apparentTemperature].round}°#{temp_unit}*"

    if sunrise.present? && sunset.present?
      sun_context = []
      sun_context << "Sunrise at *#{Time.at(sunrise).in_time_zone(dig(:timezone)).strftime('%l:%M %p')}*"
      sun_context << "Sunset at *#{Time.at(sunset).in_time_zone(dig(:timezone)).strftime('%l:%M %p')}*"
      sun_context.reverse! if sunrise > sunset
      context << sun_context
      context.flatten!
    end

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

    current_day = Time.now.in_time_zone(dig(:timezone)).beginning_of_day.to_i
    data = daily.dig(:data)&.select { |d| d[:time] > current_day }&.slice(0, 7)

    max_temp = data&.max { |a,b| a[:apparentTemperatureMax] <=> b[:apparentTemperatureMax] }
    min_temp = data&.min { |a,b| a[:apparentTemperatureMin] <=> b[:apparentTemperatureMin] }

    context = []
    context << "Low *#{min_temp[:apparentTemperatureMin].round}°#{temp_unit}* on #{Time.at(min_temp[:apparentTemperatureMinTime]).in_time_zone(dig(:timezone)).strftime('%A')}"
    context << "High *#{max_temp[:apparentTemperatureMax].round}°#{temp_unit}* on #{Time.at(max_temp[:apparentTemperatureMaxTime]).in_time_zone(dig(:timezone)).strftime('%A')}"

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

  def timestamp_block
    timestamp = dig(:currently, :time)
    return if timestamp.blank?
    updated = Time.at(timestamp).in_time_zone(dig(:timezone))

    text = if Time.now.in_time_zone(dig(:timezone)).beginning_of_day > updated
      "Updated <!date^#{timestamp}^{date_short_pretty}|#{updated.strftime('%D')}>"
    else
      "Updated at <!date^#{timestamp}^{time}|#{updated.strftime('%r')}>"
    end

    {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: text
        }
      ]
    }
  end

  def precipitation_line_chart(data:, time_format:, ticks: 24)
    return if data.blank?

    chart_config = <<~CONFIG
      {
        type: "line",
        data: {
          labels: #{data.map { |d| Time.at(d[:time]).in_time_zone(dig(:timezone)).strftime(time_format) }},
          datasets: [{
            label: "Chance of #{data.map { |d| d[:precipType] }&.compact&.uniq&.join('/') || 'precipitation'}",
            borderColor: "rgb(54, 162, 235)",
            borderWidth: 2,
            backgroundColor: "rgba(54, 162, 235, 0.5)",
            data: #{data.map { |d| d[:precipProbability] * 100 }},
            fill: "start",
            pointRadius: 0,
            lineTension: 0.4
          }]
        },
        options: {
          title: {
            display: false,
          },
          legend: {
            display: true,
            position: 'bottom',
            align: 'start',
            labels: {
              boxWidth: 4
            }
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
                  maxTicksLimit: #{ticks}
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
                  suggestedMax: 100,
                  callback: (val) => { return val + "%"; }
                }
              },
            ],
          },
        }
      }
    CONFIG

    qc = QuickChart.new(chart_config, width: 640, height: 480, device_pixel_ratio: 2.0)

    {
			"type": "image",
			"image_url": qc.get_short_url,
			"alt_text": "Chance of precipitation"
		}
  end

  def precipitation_temperature_line_chart(data:, time_format:, ticks: 24)
    return if data.blank?

    chart_config = <<~CONFIG
      {
        type: "line",
        data: {
          labels: #{data.map { |d| Time.at(d[:time]).in_time_zone(dig(:timezone)).strftime(time_format) }},
          datasets: [{
            label: "Chance of #{data.map { |d| d[:precipType] }&.compact&.uniq&.join('/') || 'precipitation'}",
            borderColor: "rgb(54, 162, 235)",
            borderWidth: 2,
            backgroundColor: "rgba(54, 162, 235, 0.5)",
            data: #{data.map { |d| d[:precipProbability] * 100 }},
            fill: "start",
            pointRadius: 0,
            lineTension: 0.4,
            yAxisID: "yChance"
          }, {
            label: "Temperature",
            borderColor: "rgb(255, 99, 132)",
            borderWidth: 2,
            backgroundColor: "rgba(255, 99, 132, 0.5)",
            data: #{data.map { |d| d[:apparentTemperature] }},
            fill: "start",
            pointRadius: 0,
            lineTension: 0.4,
            yAxisID: "yTemp"
          }]
        },
        options: {
          title: {
            display: false,
          },
          legend: {
            display: true,
            position: 'bottom',
            align: 'start',
            labels: {
              boxWidth: 4
            }
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
                  maxTicksLimit: #{ticks}
                }
              },
            ],
            yAxes: [
              {
                id: "yChance",
                display: true,
                position: "left",
                scaleLabel: {
                  display: false
                },
                ticks: {
                  beginAtZero: true,
                  suggestedMin: 0,
                  suggestedMax: 100,
                  callback: (val) => { return val + "%"; }
                }
              },
              {
                id: "yTemp",
                display: true,
                position: "right",
                scaleLabel: {
                  display: false
                },
                gridLines: {
                  drawOnChartArea: false
                },
                ticks: {
                  callback: (val) => { return val + "°#{temp_unit}"; }
                }
              }
            ],
          },
        }
      }
    CONFIG

    qc = QuickChart.new(chart_config, width: 640, height: 480, device_pixel_ratio: 2.0)

    {
			"type": "image",
			"image_url": qc.get_short_url,
			"alt_text": "Chance of precipitation & temperature"
		}
  end

  def precipitation_temperature_bar_chart(data:, time_format:, ticks: 24)
    return if data.blank?

    chart_config = <<~CONFIG
      {
        type: "bar",
        data: {
          labels: #{data.map { |d| Time.at(d[:time]).in_time_zone(dig(:timezone)).strftime(time_format) }},
          datasets: [{
            label: "Chance of #{data.map { |d| d[:precipType] }&.compact&.uniq&.join('/') || 'precipitation'}",
            borderColor: "rgb(54, 162, 235)",
            borderWidth: 2,
            backgroundColor: "rgba(54, 162, 235, 0.5)",
            categoryPercentage: 0.5,
            data: #{data.map { |d| d[:precipProbability] * 100 }},
            yAxisID: "yChance"
          }, {
            label: "Temperature",
            borderColor: "rgb(255, 99, 132)",
            borderWidth: 2,
            backgroundColor: "rgba(255, 99, 132, 0.5)",
            categoryPercentage: 0.5,
            data: #{data.map { |d| [d[:apparentTemperatureMin], d[:apparentTemperatureMax]] }},
            yAxisID: "yTemp"
          }]
        },
        options: {
          title: {
            display: false,
          },
          legend: {
            display: true,
            position: 'bottom',
            align: 'start',
            labels: {
              boxWidth: 4
            }
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
                  maxTicksLimit: #{ticks}
                }
              },
            ],
            yAxes: [
              {
                id: "yChance",
                display: true,
                position: "left",
                scaleLabel: {
                  display: false
                },
                ticks: {
                  beginAtZero: true,
                  suggestedMin: 0,
                  suggestedMax: 100,
                  callback: (val) => { return val + "%"; }
                }
              },
              {
                id: "yTemp",
                display: true,
                position: "right",
                scaleLabel: {
                  display: false
                },
                gridLines: {
                  drawOnChartArea: false
                },
                ticks: {
                  callback: (val) => { return val + "°#{temp_unit}"; }
                }
              }
            ],
          },
        }
      }
    CONFIG

    qc = QuickChart.new(chart_config, width: 640, height: 480, device_pixel_ratio: 2.0)

    {
			"type": "image",
			"image_url": qc.get_short_url,
			"alt_text": "Chance of precipitation & temperature"
		}
  end
end
