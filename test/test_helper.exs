ExUnit.start(exclude: if(System.get_env("EAB_DOCKER_TESTS") == "1", do: [], else: [:docker]))
Code.require_file("support/chatgpt_fixture_helper.exs", __DIR__)
