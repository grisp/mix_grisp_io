live_variables = ~w(GRISP_CI_USERNAME GRISP_CI_PASSWORD GRISP_CI_DEVICE)

live_api? =
  Enum.any?(live_variables, fn name ->
    System.get_env(name) not in [nil, ""]
  end)

ExUnit.start(exclude: if(live_api?, do: [], else: [live_api: true]))
