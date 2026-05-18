defmodule Misskey do
  import Deference

  defp host_url(ep) do
    "#{Cfg.get(:misskey_host)}#{ep}"
  end

  def miauth_url do
    result =
      with_defer safe: true do
        session_id = :rand.bytes(32) |> Base.url_encode64()

        query =
          URI.encode_query(
            name: Cfg.get(:app_name),
            icon: Cfg.get(:app_icon_url),
            callback: "#{Cfg.get(:app_host)}/redirect",
            permission: "read:account"
          )

        host_url("/miauth/#{session_id}/?#{query}")
      end

    result
  end

  def get_session_user(session_id) do
    Req.post(host_url("/api/miauth/#{session_id}/check"),
      body: %{token: session_id} |> JSON.encode!(),
      headers: ["Content-Type": "application/json"]
    )
    |> case do
      {:ok,
       %Req.Response{
         body: %{
           "ok" => true,
           "user" => user
         }
       }} ->
        {:ok, user}

      _ ->
        :error
    end
  end

  def get_session_info(token) do
    Req.post(host_url("/api/auth/session/show"),
      body:
        %{
          token: token
        }
        |> JSON.encode!(),
      headers: ["Content-Type": "application/json"]
    )
  end
end
