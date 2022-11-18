defmodule Reactive.MixProject do
  use Mix.Project

  def project do
    [
      app: :reactive,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package()
    ]
  end

  defp description do
    """

    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Mattias Jakobsson"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/DigitalCreationAb/reactive"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    get_application(Mix.env())
  end

  defp get_application(:test) do
    [
      extra_applications: [:logger, :crypto, :runtime_tools],
      mod: {TestApplication, []}
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
      {:elixir_uuid, "~> 1.2"},
      {:ex_doc, "~> 0.29.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
