class PreferencesPresenter < SimpleDelegator
  def to_view
    {
      type: "modal",
      callback_id: "preferences_modal",
      title: {
        type: "plain_text",
        text: "Preferences"
      },
      submit: {
        type: "plain_text",
        text: "Save"
      },
      blocks: blocks
    }
  end

  private

  def blocks
    blocks = []
    blocks << {
			type: "input",
      block_id: "location",
			element: {
				type: "plain_text_input",
				action_id: "location",
				placeholder: {
					type: "plain_text",
					text: "For which part of the world do you want to get forecasts?"
				},
        initial_value: location || ""
			},
			label: {
				type: "plain_text",
				text: "Location for forecasts"
			}
		}
    blocks << {
			type: "context",
			elements: [
				{
					type: "plain_text",
					text: "This can be an address, a city & state, or a zip/postal code.",
					emoji: true
				}
			]
		}
    blocks
  end
end
