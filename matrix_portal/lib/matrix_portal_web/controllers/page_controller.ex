defmodule MatrixPortalWeb.PageController do
  use MatrixPortalWeb, :controller
  import Deference

  def home(conn, _params) do
    login = get_session(conn, :login)

    if login do
      redirect(conn, to: "/account")
    else
      render(conn, :home)
    end
  end

  def success(conn, _params) do
    login = get_session(conn, :login)

    if login do
      render(conn, :success, %{
        avatar_url: get_session(conn, :avatar_url),
        banner_url: get_session(conn, :banner_url),
        bio: get_session(conn, :bio),
        display_name: get_session(conn, :display_name),
        user_name: get_session(conn, :user_name)
      })
    else
      redirect(conn, to: "/")
    end
  end

  def token_redirect(conn, params) do
    %{"session" => session} = params

    case Misskey.get_session_user(session) do
      {:ok,
       %{
         "avatarUrl" => avatar_url,
         "bannerUrl" => banner_url,
         "description" => bio,
         "name" => display_name,
         "username" => user_name
       }} ->
        conn
        |> put_session(:login, true)
        |> put_session(:avatar_url, avatar_url)
        |> put_session(:banner_url, banner_url)
        |> put_session(:bio, bio)
        |> put_session(:display_name, display_name || user_name)
        |> put_session(:user_name, user_name)
        |> redirect(to: "/account")

      _ ->
        conn
        |> put_flash(:error, "Invalid session token")
        |> redirect(to: "/")
    end
  end

  def account(conn, params) do
    err = Map.get(params, "err")
    login = get_session(conn, :login)

    if login do
      username = get_session(conn, :user_name)

      if Matrix.user_exists?(username) do
        render(conn, :account_exists, %{
          avatar_url: get_session(conn, :avatar_url),
          banner_url: get_session(conn, :banner_url),
          bio: get_session(conn, :bio),
          display_name: get_session(conn, :display_name),
          user_name: username
        })
      else
        render(conn, :new_account, %{
          err: err,
          avatar_url: get_session(conn, :avatar_url),
          banner_url: get_session(conn, :banner_url),
          bio: get_session(conn, :bio),
          display_name: get_session(conn, :display_name),
          user_name: username
        })
      end
    else
      conn
      |> put_flash(:error, "Invalid session")
      |> redirect(to: "/")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:login)
    |> delete_session(:avatar_url)
    |> delete_session(:banner_url)
    |> delete_session(:bio)
    |> delete_session(:display_name)
    |> delete_session(:user_name)
    |> put_flash(:info, "Signed out")
    |> redirect(to: "/")
  end

  def create_account(conn, params) do
    %{
      "password" => password,
      "password_conf" => password_conf,
      "display_name" => display_name
    } = params

    with_defer do
      if password != password_conf do
        throw_err({:error, "Passwords do not match"})
      end

      if password == "" do
        throw_err({:error, "Passwords may not be blank!"})
      end

      Matrix.create_account(
        username: get_session(conn, :user_name),
        password: password,
        avatar_url: get_session(conn, :avatar_url),
        banner_url: get_session(conn, :banner_url),
        bio: get_session(conn, :bio),
        display_name: display_name
      )

      # rescue
      #   e ->
      #     IO.inspect(e)
      #     {:error, "Internal Server Error"}
    end
    |> case do
      :ok ->
        conn
        |> redirect(to: "/success")

      {:error, message} ->
        q = URI.encode_query(err: message)

        conn
        |> redirect(to: "/account?#{q}")

      _ ->
        q = URI.encode_query(err: "Internal server error, contact an admin!")

        conn
        |> redirect(to: "/account?#{q}")
    end
  end
end
