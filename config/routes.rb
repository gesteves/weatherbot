Rails.application.routes.draw do
  get 'home/index'
  get 'home/success'
  require "sidekiq/web"
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])) &
    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
  end if Rails.env.production?
  mount Sidekiq::Web, at: "/sidekiq"

  get  "/success"            => "home#success",       :as => "success"

  # Slack endpoints
  get  "/slack/auth"         => "slack#auth",         :as => "auth"
  post "/slack/interactions" => "slack#interactions", :as => "interactions"
  post "/slack/events"       => "slack#events",       :as => "events"
  post "/slack/slash"        => "slack#slash",        :as => "slash"
  # Defines the root path route ("/")
  root "home#index"
end
