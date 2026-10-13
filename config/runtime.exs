import Config

if config_env() != :test do
  data = System.get_env("EAB_DATA_DIR", ".local/app") |> Path.expand()
  File.mkdir_p!(data)
  File.chmod!(data, 0o700)
  secret_path = Path.join(data, "session-secret")

  unless File.exists?(secret_path) do
    File.write!(secret_path, Base.encode64(:crypto.strong_rand_bytes(64)), [:exclusive])
    File.chmod!(secret_path, 0o600)
  end

  config :eab,
    data_dir: data,
    root: System.get_env("EAB_ROOT", File.cwd!())

  config :eab, :pipeline,
    lookahead: String.to_integer(System.get_env("EAB_PREPARE_AHEAD", "4")),
    preparation_workers: String.to_integer(System.get_env("EAB_PREPARE_WORKERS", "2"))

  config :eab, EabWeb.Endpoint,
    secret_key_base: File.read!(secret_path),
    http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "4000"))],
    server: true
end
