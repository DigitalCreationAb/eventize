defmodule Eventize.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :eventize,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/DigitalCreationAb/eventize"
    ]
  end

  defp description do
    """
    Eventize can be used to create persistent processes using EventSourcing.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Mattias Jakobsson"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/DigitalCreationAb/eventize"}
    ]
  end

  defp docs do
    []
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    get_application(Mix.env())
  end

  defp get_application(:test) do
    [
      extra_applications: [:logger, :crypto, :runtime_tools]
    ]
  end

  defp get_application(_) do
    [
      extra_applications: [:logger, :crypto, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.3"},
      {:elixir_uuid, "~> 1.2"},
      {:ex_doc, "~> 0.29.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
