Mix.install(
  [
    {:ecto_sql, "~> 3.10"},
    {:postgrex, ">= 0.0.0"}
  ],
  config: [
    {
      :foo,
      [
        {
          Repo,
          [
            database: "mix_install_examples",
            stacktrace: true,
            show_sensitive_data_on_connection_error: true,
            ownership_timeout: 360_000_000,
            timeout: :infinity,
            pool_size: 10,
            pool: Ecto.Adapters.SQL.Sandbox
          ]
        }
      ]
    }
  ]
)

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
  import Ecto.Query, warn: false

  defp setup do
    _ = Repo.__adapter__().storage_down(Repo.config())
    :ok = Repo.__adapter__().storage_up(Repo.config())

    children = [
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

  def run do
    alias Ecto.Multi

    setup()

    Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

    _repo_owner_pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: false)

    Repo.insert!(%Post{title: "Hello, World!"})

    allowed_pid = self()

    spawn(fn ->
      {:ok, %{posts: posts}} =
        Multi.new()
        |> Multi.run(:posts, fn repo, _changes ->
          posts = from(Post) |> repo.all(caller: allowed_pid)

          {:ok, posts}
        end)
        |> Repo.transaction(caller: allowed_pid)

      send(allowed_pid, {:posts, posts})
    end)

    receive do
      {:posts, posts} ->
        IO.inspect(posts)
    after
      1_000 ->
        :ok
    end
  end
end

Main.run()
