# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :minuteiro, :scopes,
  user: [
    default: true,
    module: Minuteiro.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Minuteiro.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :minuteiro,
  ecto_repos: [Minuteiro.Repo],
  generators: [timestamp_type: :utc_datetime],
  bootstrap_sample_template: false

config :minuteiro, Minuteiro.AI,
  client: Minuteiro.AI.GeminiClient,
  base_url: "https://generativelanguage.googleapis.com/v1beta",
  model: "gemini-2.0-flash",
  timeout_ms: 30_000

# Configures the endpoint
config :minuteiro, MinuteiroWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MinuteiroWeb.ErrorHTML, json: MinuteiroWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Minuteiro.PubSub,
  live_view: [signing_salt: "Azfip2HS"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :minuteiro, Minuteiro.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  minuteiro: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  minuteiro: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
