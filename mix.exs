defmodule XFsm.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/heywhy/xfsm"

  def project do
    [
      app: :xfsm,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Declarative finite state machine",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @source_url}
      ],

      # Docs
      name: "XFsm",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: &docs/0
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
      {:castore, "~> 1.0", only: [:test]},
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: [:test]},
      {:git_hooks, "~> 0.8", only: :dev, runtime: false},
      {:git_ops, "~> 2.6", only: :dev, runtime: false}
    ]
  end

  defp aliases, do: [setup: ["deps.get", "git_hooks.install"]]

  defp docs do
    [
      main: "quickstart",
      assets: %{"docs/js" => "js"},
      before_closing_head_tag: &before_closing_head_tag/1,
      extras: [
        "docs/quickstart.md",
        "docs/installation.md",
        "docs/cheatsheet.cheatmd",
        {:"docs/state-machines.md", [title: "State machines"]},
        {:"README.md", [title: "What is XFsm"]},
        "docs/machines.md",
        "docs/input.md",
        "docs/transitions.md",
        "docs/eventless-transitions.md",
        "docs/actions.md",
        "docs/guards.md"
      ],
      groups_for_extras: [
        "Get started": [
          "docs/quickstart.md",
          "docs/installation.md",
          "docs/cheatsheet.cheatmd"
        ],
        "Core concept": ["docs/state-machines.md", "README.md"],
        "State machines": [
          "docs/machines.md",
          "docs/input.md",
          "docs/transitions.md",
          "docs/eventless-transitions.md",
          "docs/actions.md",
          "docs/guards.md"
        ]
      ]
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@11.6.0/dist/mermaid.min.js"></script>
    <script src="js/renderer.js"></script>
    """
  end

  defp before_closing_head_tag(:epub), do: ""
end
