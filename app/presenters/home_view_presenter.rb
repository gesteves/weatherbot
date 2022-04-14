class HomeViewPresenter < SimpleDelegator
  def to_view
    blocks = if location.blank?
      onboarding_blocks
    else
      forecast_blocks
    end

    {
      type: "home",
      blocks: blocks
    }
  end

  def onboarding_view
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
        text: "Welcome to #{team.bot_mention}! I can show you detailed weather forecasts for your location, right here on my Home tab, powered by <https://darksky.net/poweredby/|Dark Sky>. I can also give you weather forecast for any location in the world, just type `/weather` followed by a location (like a city, zip code, or even a specific address) in any channel."
      }
    }

    blocks << {
      type: "section",
      text: {
        type: "mrkdwn",
        text: "Before I can show you your personalized forecast here, though, I need to know where you’re located. Simply click the button below to set it up:"
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
          "value": "preferences"
        }
      ]
    }

    blocks
  end

  def forecast_view

  end
end
