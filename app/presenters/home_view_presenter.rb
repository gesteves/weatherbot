class HomeViewPresenter < SimpleDelegator
  def to_view
    blocks = Rails.cache.fetch("/user/#{slack_id}/home/#{location}", expires_in: 10.minutes) do
      if location.blank?
        onboarding_blocks
      else
        forecast_blocks
      end
    end

    {
      type: "home",
      blocks: blocks
    }
  end

  def onboarding_blocks
    blocks = []
    blocks << {
      type: "section",
      text: {
        type: "mrkdwn",
        text: ":wave: Howdy #{display_name},"
      }
    }
    blocks << {
      type: "section",
      text: {
        type: "mrkdwn",
        text: "Welcome to #{team.bot_mention}! I can show you detailed weather forecasts for your location, right here on my Home tab, powered by <https://darksky.net/poweredby/|Dark Sky>.\n\nI can also give you a weather forecast for any location in the world, by typing `/weather` followed by a location, such as:\n\n• `/weather in washington, dc`\n• `/weather 20001`\n• `/weather at 1600 pennsylvania avenue nw, washington, dc`.\n\nBefore I can show you your personalized forecast here, though, I need to know where you’re located. Simply click the button below to set it up:"
      }
    }

    blocks << {
      type: "actions",
      elements: [
        {
          type: "button",
          text: {
            type: "plain_text",
            text: "Preferences",
            "emoji": true
          },
          action_id: "open_preferences"
        }
      ]
    }

    blocks
  end

  def forecast_blocks
    blocks = ForecastPresenter.new(forecast).long_forecast_blocks
    blocks << {
      type: "divider"
    }
    blocks << {
      type: "actions",
      elements: [
        {
          type: "button",
          text: {
            type: "plain_text",
            text: "Preferences",
            "emoji": true
          },
          action_id: "open_preferences"
        }
      ]
    }
    blocks
  end
end
