class SlackController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :no_cache
  before_action :parse_event, only: :events
  before_action :parse_interaction, only: :interactions
  before_action :parse_slash, only: :slash
  before_action :check_token, only: [:events, :interactions, :slash]
  before_action :check_team, only: :slash
  before_action :verify_url, only: :events

  def auth
    url = root_url
    if params[:code].present?
      slack = Slack.new
      token = slack.get_access_token(code: params[:code], redirect_uri: auth_url)
      if token[:ok]
        access_token = token[:access_token]
        team_id = token.dig(:team, :id)
        team = Team.find_or_create_by(slack_id: team_id)
        team.access_token = access_token
        team.scopes = token[:scope]
        if team.save
          notice = nil
          url = success_url
        else
          notice = 'Oh no, something went wrong. Please try again!'
        end
      else
        logger.error "[LOG] Authentication failed for the following reason: #{token[:error]}"
        notice = "Oh no, something went wrong. Please try again!"
      end
    elsif params[:error].present?
      logger.error "[LOG] Authentication failed for the following reason: #{params[:error]}"
      notice = "Trebekbot was not added to your Slack. Please try again!"
    end
    redirect_to url, notice: notice, allow_other_host: true
  end

  def events
    case @event_type
    when 'app_home_opened'
      app_home_opened
    when 'app_uninstalled'
      app_uninstalled
    end

    render plain: "OK", status: 200
  end

  def interactions
    case @payload_type
    when 'block_actions'
      actions = @payload.dig(:actions)&.map { |a| a[:action_id] }
      open_preferences if actions&.include? 'open_preferences'
    when 'view_submission'
      @values = @payload.dig(:view, :state, :values)
      save_preferences if @payload.dig(:view, :callback_id) == 'preferences_modal'
    end
    render plain: "", status: 200
  end

  def slash
    case @command
    when "/weather", "/weatherbot"
      slash_weather
    end
    response = { response_type: "in_channel" }
    render json: response, status: 200
  end

  private

  def check_token
    render plain: "Unauthorized", status: 401 if @token != ENV['SLACK_VERIFICATION_TOKEN']
  end

  def check_team
    team = Team.find_by(slack_id: @team)
    unless team&.has_correct_scopes?
      response = { text: "This app has been updated and requires new permissions; please visit #{root_url} to reinstall it. Thanks!", response_type: 'ephemeral', unfurl_links: true }
      render json: response, status: 200
    end
  end

  def parse_event
    @token = params[:token]
    @event_type = params.dig(:event, :type) || params[:type]
    @text = params.dig(:event, :text)
    @team = params[:team_id]
    @channel = params.dig(:event, :channel)
    @user = params.dig(:event, :user)
    @thread_ts = params.dig(:event, :thread_ts)
  end

  def parse_interaction
    begin
      @payload = JSON.parse(params[:payload], symbolize_names: true)
    rescue
      return render plain: "Bad Request", status: 400
    end

    @payload_type = @payload[:type]
    @token = @payload[:token]
    @user = @payload.dig(:user, :id)
    @team = @payload.dig(:team, :id)
    @channel = @payload.dig(:channel, :id)
    @ts = @payload.dig(:message, :ts)
    @trigger_id = @payload.dig(:trigger_id)
  end

  def parse_slash
    @token = params[:token]
    @team = params[:team_id]
    @channel = params[:channel_id]
    @user = params[:user_id]
    @command = params[:command]
    @text = params[:text]
    @response_url = params[:response_url]
  end

  # EVENT HANDLERS

  def verify_url
    render plain: params[:challenge], status: 200 if @event_type == 'url_verification'
  end

  def app_home_opened
    UpdateAppHomeWorker.perform_async(@team, @user)
  end


  def app_uninstalled
    team = Team.find_by(slack_id: @team)
    team.destroy
  end

  # INTERACTION HANDLERS

  def open_preferences
    OpenPreferencesWorker.perform_async(@team, @user, @trigger_id)
  end

  def save_preferences
    location = @values.dig(:location, :location, :value)
    user = User.find_by(slack_id: @user)
    user.location = location
    user.save!
    UpdateAppHomeWorker.perform_async(@team, @user)
  end

  # SLASH HANDLERS

  def slash_weather
    location = @text.sub(/^\s+(at|in|on|for)\s+/i, '')

    logger.info "Forecast requested for: #{location}"
    PostForecastWorker.perform_async(location, @response_url)
  end
end
