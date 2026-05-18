defmodule Cfg do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    table =
      :ets.new(__MODULE__, [
        :public,
        :named_table,
        read_concurrency: true
      ])

    :ets.insert(__MODULE__, [
      {:matrix_delegate, System.fetch_env!("MATRIX_DELEGATE")},
      {:matrix_host, System.fetch_env!("MATRIX_HOST")},
      {:matrix_psk, System.fetch_env!("MATRIX_PSK")},
      {:matrix_admin_user, System.fetch_env!("MATRIX_ADMIN_USER")},
      {:matrix_admin_pass, System.fetch_env!("MATRIX_ADMIN_PASS")},
      {:matrix_joins, System.fetch_env!("MATRIX_JOINS")},
      {:matrix_client, System.fetch_env!("MATRIX_CLIENT")},
      {:misskey_host, System.fetch_env!("MISSKEY_HOST")},
      {:misskey_name, System.fetch_env!("MISSKEY_NAME")},
      {:app_host, System.fetch_env!("APP_HOST")},
      {:app_name, System.fetch_env!("APP_NAME")},
      {:app_icon_url, System.fetch_env!("APP_ICON_URL")}
    ])

    {:ok, table}
  end

  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> value
      _ -> throw("Invalid config lookup!")
    end
  end
end
