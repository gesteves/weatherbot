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
    blocks << divider
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
    blocks << precipitation_line_chart(data: dig(:minutely, :data), time_format: '%l:%M %P', ticks: 28)
    blocks << divider
    blocks << hourly_block
    blocks << precipitation_temperature_line_chart(data: dig(:hourly, :data)&.select { |d| d[:time] > Time.now.to_i }&.slice(0, 24), time_format: '%l %P')
    blocks << divider
    blocks << daily_block
    blocks << precipitation_temperature_combo_chart(data: dig(:daily, :data)&.select { |d| d[:time] > Time.now.to_i }&.slice(0, 7), time_format: '%A')
    blocks << divider
    blocks.flatten.compact
  end

  private

  def icon_accessory(icon)
    available = %w{
      clear-day
      clear-night
      rain
      snow
      sleet
      wind
      fog
      cloudy
      partly-cloudy-day
      partly-cloudy-night
      hail
      thunderstorm
      tornado
    }
    return unless available.include? icon

    {
      type: "image",
      image_url: ActionController::Base.helpers.image_url("icons/#{icon}.png"),
      alt_text: icon.titleize
    }
  end

  def divider
    {	type: "divider" }
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

    summary = "#{currently.dig(:summary).sub(/\.$/, '')}, #{currently.dig(:temperature).round}°#{temp_unit}"

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
        },
        accessory: icon_accessory(currently.dig(:icon))
      }.compact,
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

    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Next hour*\n#{summary.strip}"
        },
        accessory: icon_accessory(minutely.dig(:icon))
      }.compact
    ]
  end

  def hourly_block
    hourly = dig(:hourly)
    return if hourly.blank?

    summary = hourly.dig(:summary)

    now = Time.now.to_i
    data = hourly.dig(:data)&.select { |d| d[:time] > now }&.slice(0, 24)

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
        },
        accessory: icon_accessory(hourly.dig(:icon))
      }.compact,
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

    summary = daily.dig(:summary)

    now = Time.now.to_i
    data = daily.dig(:data)&.select { |d| d[:time] > now }&.slice(0, 7)

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
        },
        accessory: icon_accessory(daily.dig(:icon))
      }.compact,
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
    {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: "Updated at <!date^#{timestamp}^{time}|#{Time.at(timestamp).strftime('%r')}>"
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
            pointRadius: 0,
            lineTension: 0.4,
            yAxisID: "yChance"
          }, {
            label: "Temperature",
            borderColor: "rgb(255, 99, 132)",
            borderWidth: 2,
            backgroundColor: "rgba(255, 99, 132, 0.5)",
            data: #{data.map { |d| d[:apparentTemperature] }},
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

  def precipitation_temperature_combo_chart(data:, time_format:, ticks: 24)
    return if data.blank?

    chart_config = <<~CONFIG
      {
        type: "bar",
        data: {
          labels: #{data.map { |d| Time.at(d[:time]).in_time_zone(dig(:timezone)).strftime(time_format) }},
          datasets: [{
            type: "line",
            label: "Chance of #{data.map { |d| d[:precipType] }&.compact&.uniq&.join('/') || 'precipitation'}",
            borderColor: "rgb(54, 162, 235)",
            borderWidth: 2,
            backgroundColor: "rgba(54, 162, 235, 0.5)",
            data: #{data.map { |d| d[:precipProbability] * 100 }},
            fill: false,
            pointRadius: 0,
            lineTension: 0.4,
            yAxisID: "yChance"
          }, {
            label: "Temperature",
            barPercentage: 0.5,
            borderColor: "rgb(255, 99, 132)",
            borderWidth: 2,
            backgroundColor: "rgba(255, 99, 132, 0.5)",
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
