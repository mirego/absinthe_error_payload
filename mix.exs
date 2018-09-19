defmodule Kronky.Mixfile do
  use Mix.Project

  @version "0.5.0"

  def project do
    [
      app: :kronky,
      version: @version,
      elixir: "~> 1.4",
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
      # docs
      name: "Kronky",
      source_url: "https://github.com/Ethelo/kronky",
      homepage_url: "https://github.com/Ethelo/kronky",
      docs: [
        # The main page in the docs
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger], env: [field_constructor: Kronky.FieldConstructor]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.4.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ecto, ">= 2.1.4"},
      {:absinthe, "~> 1.3"},
      {:credo, "~> 0.7.4", only: [:dev, :test]},
      {:excoveralls, "~> 0.6", only: :test},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Utilities to return ecto validation error messages in an absinthe graphql response.
    """
  end

  defp package do
    [
      maintainers: ["Laura Ann Williams (law)", "Ethelo.com"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Ethelo/kronky",
        "HexDocs" => "https://hexdocs.pm/kronky"
      }
    ]
  end
end
