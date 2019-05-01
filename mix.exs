defmodule AbsintheErrorPayload.Mixfile do
  use Mix.Project

  @version "1.0.1"

  def project do
    [
      app: :absinthe_error_payload,
      version: @version,
      elixir: "~> 1.6",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      name: "AbsintheErrorPayload",
      source_url: "https://github.com/mirego/absinthe_error_payload",
      homepage_url: "https://github.com/mirego/absinthe_error_payload",
      docs: [
        # The main page in the docs
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger], env: [field_constructor: AbsintheErrorPayload.FieldConstructor]]
  end

  defp deps do
    [
      {:ecto, "~> 3.1"},
      {:absinthe, "~> 1.3"},
      {:excoveralls, "~> 0.6", only: :test},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Utilities to return Ecto validation error messages in an absinthe graphql response.
    """
  end

  defp package do
    [
      maintainers: ["Simon Prévost"],
      licenses: ["BSD-3"],
      links: %{
        "GitHub" => "https://github.com/mirego/absinthe_error_payload"
      }
    ]
  end
end
