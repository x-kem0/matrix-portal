defmodule Matrix do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    table =
      :ets.new(__MODULE__, [
        :named_table,
        :public,
        read_concurrency: true
      ])

    get_api_key()
    {:ok, table}
  end

  def deactivate_user(username) do
    auth_post(
      "/_synapse/admin/v1/deactivate/@#{username}:#{Cfg.get(:matrix_delegate)}",
      %{
        erase: true
      }
    )
  end

  def user_exists?(username) do
    auth_get("/_synapse/admin/v2/users/@#{username}:#{Cfg.get(:matrix_delegate)}")
    |> case do
      {:ok,
       %Req.Response{
         status: 200
       }} ->
        true

      {:ok,
       %Req.Response{
         status: 404
       }} ->
        false
    end
  end

  def get_user_access_token(username) do
    {:ok, %{body: %{"access_token" => access_token}}} =
      auth_post("/_synapse/admin/v1/users/#{fmt_username(username)}/login", %{})

    access_token
  end

  def create_account(
        username: username,
        password: password,
        avatar_url: avatar_url,
        banner_url: banner_url,
        bio: bio,
        display_name: display_name
      ) do
    if user_exists?(username) do
      {:error, :user_exists}
    else
      nonce = get_nonce()
      psk = Cfg.get(:matrix_psk)

      hmac =
        :crypto.mac(
          :hmac,
          :sha,
          psk,
          Enum.join(
            [
              nonce,
              username,
              password,
              "notadmin"
            ],
            <<0>>
          )
        )
        |> Base.encode16(case: :lower)

      payload = %{
        nonce: nonce,
        username: username,
        password: password,
        mac: hmac,
        admin: false,
        user_type: nil
      }

      auth_post("/_synapse/admin/v1/register", payload)
      |> case do
        {:ok, %{status: 200, body: %{"access_token" => user_access_token}}} ->
          post_account_setup(
            username,
            user_access_token,
            avatar_url,
            bio,
            display_name,
            banner_url
          )

          :ok

        _ ->
          {:error, "Account creation failed"}
      end

      :ok
    end
  end

  defp post_account_setup(
         username,
         user_access_token,
         avatar_url,
         bio,
         display_name,
         banner_url
       ) do
    :logger.debug("UAT: #{user_access_token}")
    {:ok, resp} = Req.get(avatar_url)
    avatar_filename = get_resp_filename(resp)
    avatar_mime = get_resp_content_type(resp)
    avatar_mxc = create_media(user_access_token)
    put_media(avatar_mxc, resp.body, avatar_filename, avatar_mime, user_access_token)

    Req.put(host_url("/_matrix/client/v3/profile/#{fmt_username(username)}/avatar_url"),
      body: %{avatar_url: avatar_mxc} |> JSON.encode!(),
      headers: [
        "content-type": "application/json",
        authorization: "Bearer #{user_access_token}"
      ]
    )

    if display_name do
      Req.put(host_url("/_matrix/client/v3/profile/#{fmt_username(username)}/displayname"),
        body: %{displayname: display_name} |> JSON.encode!(),
        headers: [
          "content-type": "application/json",
          authorization: "Bearer #{user_access_token}"
        ]
      )
    end

    if bio do
      bio_fmt = Formatter.fmt_bio(bio)

      Req.put(host_url("/_matrix/client/v3/profile/#{fmt_username(username)}/moe.sable.app.bio"),
        body:
          %{
            "moe.sable.app.bio" => bio_fmt
          }
          |> JSON.encode!(),
        headers: [
          "content-type": "application/json",
          authorization: "Bearer #{user_access_token}"
        ]
      )

      Req.put(host_url("/_matrix/client/v3/profile/#{fmt_username(username)}/gay.fomx.biography"),
        body:
          %{
            "gay.fomx.biography" => [
              %{
                body: bio_fmt,
                mimetype: "text/html"
              },
              %{body: bio}
            ]
          }
          |> JSON.encode!(),
        headers: [
          "content-type": "application/json",
          authorization: "Bearer #{user_access_token}"
        ]
      )

      Req.put(
        host_url("/_matrix/client/v3/profile/#{fmt_username(username)}/chat.commet.profile_bio"),
        body:
          %{
            "chat.commet.profile_bio" => %{
              format: "org.matrix.custom.html",
              formatted_body: bio_fmt
            }
          }
          |> JSON.encode!(),
        headers: [
          "content-type": "application/json",
          authorization: "Bearer #{user_access_token}"
        ]
      )
    end

    if banner_url do
      {:ok, resp} = Req.get(banner_url)
      banner_filename = get_resp_filename(resp)
      banner_mime = get_resp_content_type(resp)
      banner_mxc = create_media(user_access_token)
      put_media(banner_mxc, resp.body, banner_filename, banner_mime, user_access_token)

      Req.put(
        host_url(
          "/_matrix/client/v3/profile/#{fmt_username(username)}/chat.commet.profile_banner"
        ),
        body: %{"chat.commet.profile_banner" => banner_mxc} |> JSON.encode!(),
        headers: [
          "content-type": "application/json",
          authorization: "Bearer #{user_access_token}"
        ]
      )
    end

    for space <- Cfg.get(:matrix_joins) |> String.split(" ") do
      :logger.debug("Joining #{space}")

      Req.post(
        host_url("/_matrix/client/v3/join/#{space |> URI.encode_www_form()}"),
        headers: [
          authorization: "Bearer #{user_access_token}"
        ]
      )
    end

    Req.post(
      host_url("/_matrix/client/v3/logout"),
      headers: [
        authorization: "Bearer #{user_access_token}"
      ]
    )
  end

  defp create_media(access_token) do
    %{body: %{"content_uri" => mxc}} =
      Req.post!(host_url("/_matrix/media/v1/create"),
        headers: [
          authorization: "Bearer #{access_token}"
        ]
      )

    mxc
  end

  defp put_media(mxc, bytes, filename, mimetype, access_token) do
    "mxc://" <> rest = mxc
    [server, id] = String.split(rest, "/")
    query = URI.encode_query(filename: filename)

    Req.put(
      host_url("/_matrix/media/v3/upload/#{server}/#{id}?#{query}"),
      body: bytes,
      headers: [
        "content-type": mimetype,
        authorization: "Bearer #{access_token}"
      ]
    )
  end

  defp get_resp_filename(resp) do
    try do
      %Req.Response{
        headers: %{
          "content-disposition" => [disposition | _]
        }
      } = resp

      "inline; filename=" <> filename = disposition
      String.replace(filename, "\"", "")
    rescue
      # using default png avatar
      _ -> "avatar.png"
    end
  end

  defp get_resp_content_type(resp) do
    %Req.Response{
      headers: %{
        "content-type" => [type | _]
      }
    } = resp

    type
  end

  defp fmt_username(username) do
    "@#{username}:#{Cfg.get(:matrix_delegate)}"
  end

  defp auth_get(ep) do
    Req.get(host_url(ep), headers: [authorization: "Bearer #{get_api_key()}"])
  end

  defp auth_post(ep, body) do
    Req.post(host_url(ep),
      body: body |> JSON.encode!(),
      headers: [authorization: "Bearer #{get_api_key()}"]
    )
  end

  defp host_url(ep) do
    "#{Cfg.get(:matrix_host)}#{ep}"
  end

  defp get_api_key do
    case :ets.lookup(__MODULE__, :access_token) do
      [{:access_token, {key, expiry}}] ->
        if DateTime.after?(DateTime.utc_now(), expiry) do
          :logger.debug("Key expired")
          :ets.delete(__MODULE__, :access_token)
          get_api_key()
        else
          key
        end

      _ ->
        %{body: %{"access_token" => access_token}} =
          Req.post!(host_url("/_matrix/client/v3/login"),
            body:
              %{
                type: "m.login.password",
                user: Cfg.get(:matrix_admin_user),
                password: Cfg.get(:matrix_admin_pass),
                refresh_token: false
              }
              |> JSON.encode!()
          )

        :ets.insert(
          __MODULE__,
          {:access_token, {access_token, DateTime.add(DateTime.utc_now(), 3600)}}
        )

        access_token
    end
  end

  defp get_nonce() do
    %{body: %{"nonce" => nonce}} = Req.get!(host_url("/_synapse/admin/v1/register"))
    nonce
  end
end
