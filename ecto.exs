Application.put_env(:foo, Repo,
  database: "mix_install_examples",
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
  {:ecto_sql, "~> 3.10"},
  {:postgrex, ">= 0.0.0"},
  {:cachex, "~> 3.4"}
])

defmodule Repo do
  use Ecto.Repo,
    adapter: Ecto.Adapters.Postgres,
    otp_app: :foo
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

defmodule Main do
  require Logger
  import Ecto.Query, warn: false

  defp setup do
    _ = Repo.__adapter__().storage_down(Repo.config())
    :ok = Repo.__adapter__().storage_up(Repo.config())

    children = [
      {Cachex, name: :foo_cache},
      Repo
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    Ecto.Migrator.run(
      Repo,
      [{0, Migration0}],
      :up,
      all: true,
      log_migrations_sql: :debug
    )
  end

  defp get(repo_owner_pid) do
    alias Ecto.Multi

    allowed_pid = self()

    repo_opts = [caller: allowed_pid]
    _repo_opts = [caller: repo_owner_pid]

    Cachex.fetch(:foo_cache, :whatever, fn ->
      debug_log(self(), "cachex process PID")

      posts =
        from(Post)
        |> Repo.all(repo_opts)

      {:commit, posts}
    end)
    |> elem(1)
    |> debug_log()
  end

  def run do
    setup()

    Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

    repo_owner_pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: false)

    Repo.insert!(%Post{title: "Hello, World!"})

    get(repo_owner_pid)
  end

  def debug_log(args, label \\ "Degugging...") do
    opts = Inspect.Opts.new([])
    doc = Inspect.Algebra.group(Inspect.Algebra.to_doc(args, opts))
    chardata = Inspect.Algebra.format(doc, opts.width)

    label =
      if is_binary(label) do
        label
      else
        inspect(label)
      end

    Logger.info([
      "\n\n\n",
      "Start ===  #{label}  ===\n",
      "-------------------------------------------------------------------------------\n",
      chardata,
      "\n-------------------------------------------------------------------------------",
      "\nEnd ===  #{label}  ===\n\n\n"
    ])

    args
  end
end

Main.run()
