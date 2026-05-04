# Used by "mix format"
locals_without_parens = [
  action: 1,
  action: 2,
  context: 1,
  context: 2,
  entry: 1,
  entry: 2,
  exit: 1,
  exit: 2,
  guard: 1,
  guard: 2,
  initial: 1,
  target: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
