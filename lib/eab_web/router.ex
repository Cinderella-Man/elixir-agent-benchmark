defmodule EabWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:protect_from_forgery)

    plug(:put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self' ws://localhost:* ws://127.0.0.1:*; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"
    })

    plug(:put_root_layout, html: {EabWeb.Layouts, :root})
  end

  scope "/", EabWeb do
    pipe_through(:browser)
    live("/", DashboardLive)
    get("/artifacts/:id/*path", ArtifactController, :show)
  end
end
