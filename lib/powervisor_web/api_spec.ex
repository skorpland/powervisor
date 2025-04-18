defmodule PowervisorWeb.ApiSpec do
  @moduledoc false

  alias OpenApiSpex.Info
  alias OpenApiSpex.OpenApi
  alias OpenApiSpex.Paths
  alias OpenApiSpex.SecurityScheme
  alias OpenApiSpex.Server

  alias PowervisorWeb.Endpoint
  alias PowervisorWeb.Router

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    OpenApiSpex.resolve_schema_modules(%OpenApi{
      servers: [Server.from_endpoint(Endpoint)],
      info: %Info{
        title: to_string(Application.spec(:powervisor, :description)),
        version: to_string(Application.spec(:powervisor, :vsn))
      },
      paths: Paths.from_router(Router),
      security: [%{"authorization" => [%SecurityScheme{type: "http", scheme: "bearer"}]}]
    })
  end
end
