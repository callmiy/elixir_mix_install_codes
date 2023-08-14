Application.put_env(:phoenix, :json_library, Jason)

Application.put_env(:phoenix_ecto_sandbox_playwright, PhoenixEctoSandboxPlaywright.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  server: true,
  secret_key_base: String.duplicate("a", 64),
  debug_errors: true
)

Application.put_env(:phoenix_ecto_sandbox_playwright, Repo,
  database: "phoenix_ecto_sandbox_playwright",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  ownership_timeout: 360_000_000,
  timeout: :infinity,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox
)

Mix.install([
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.2"},
  {:phoenix, "~> 1.7.7"},
  {:phoenix_html, "~> 3.3.2"},
  {:phoenix_ecto, "~> 4.4"},
  {:ecto_sql, "~> 3.10"},
  {:postgrex, ">= 0.0.0"}
])

defmodule Repo do
  use Ecto.Repo,
    adapter: Ecto.Adapters.Postgres,
    otp_app: :phoenix_ecto_sandbox_playwright
end

defmodule Migration0 do
  use Ecto.Migration

  def change do
    create table("posts") do
      add(:title, :string)
      timestamps(type: :utc_datetime_usec)
    end
  end
end

defmodule Post do
  use Ecto.Schema

  schema "posts" do
    field(:title, :string)
    timestamps(type: :utc_datetime_usec)
  end
end

defmodule PhoenixEctoSandboxPlaywright.ErrorView do
  def render(template, _) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule PhoenixEctoSandboxPlaywright.IndexController do
  use Phoenix.Controller
  import Ecto.Query, warn: false

  def index(conn, _) do
    _p =
      from(Post)
      |> Repo.all()

    text(conn, "Hello, World!")
  end

  def favicon(conn, _), do: text(conn, "i")
end

defmodule Router do
  use Phoenix.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", PhoenixEctoSandboxPlaywright do
    pipe_through(:browser)

    get("/", IndexController, :index)

    get("/favicon.ico", IndexController, :favicon)
  end
end

defmodule PhoenixEctoSandboxPlaywright.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_ecto_sandbox_playwright

  plug(Phoenix.Ecto.SQL.Sandbox,
    at: "/sandbox",
    repo: Repo,
    timeout: 15000,
    header: "sandbox"
  )

  plug(Router)
end

_ = Repo.__adapter__().storage_down(Repo.config())
:ok = Repo.__adapter__().storage_up(Repo.config())

{:ok, _} =
  Supervisor.start_link(
    [
      Repo,
      PhoenixEctoSandboxPlaywright.Endpoint
    ],
    strategy: :one_for_one
  )

Ecto.Migrator.run(
  Repo,
  [{0, Migration0}],
  :up,
  all: true,
  log_migrations_sql: :debug
)

Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

Process.sleep(:infinity)
