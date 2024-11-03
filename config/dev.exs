import Config

config :git_hooks,
  auto_install: true,
  hooks: [
    commit_msg: [
      tasks: [
        {:cmd, "mix git_ops.check_message", include_hook_args: true}
      ]
    ],
    pre_commit: [
      tasks: [
        {:mix_task, :credo, ["--strict"]},
        {:mix_task, :format, ["--check-formatted"]}
      ]
    ],
    pre_push: [
      tasks: [
        {:mix_task, :dialyzer},
        {:mix_task, :test, ["--color"]}
      ]
    ]
  ]

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/heywhy/xfsm",
  manage_mix_version?: true,
  manage_readme_version: "README.md",
  version_tag_prefix: "v"
