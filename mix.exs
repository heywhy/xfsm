defmodule XFsm.MixProject do
  use Mix.Project

  @version "0.1.2"
  @source_url "https://github.com/heywhy/xfsm"

  def project do
    [
      app: :xfsm,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Declarative finite state machine",
      source_url: @source_url,
      homepage_url: @source_url,
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @source_url}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      registered: [XFsm.Timers],
      mod: {XFsm.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:git_hooks, "~> 0.8", only: :dev, runtime: false},
      {:git_ops, "~> 2.6", only: :dev, runtime: false}
    ]
  end

  defp aliases, do: [setup: ["deps.get", "git_hooks.install"]]
end
