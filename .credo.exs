# config/.credo.exs
%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 11},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true}
      ]
    }
  ]
}
