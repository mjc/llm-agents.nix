{
  lib,
  stdenv,
  flake,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  cacert,
  bash,
  bubblewrap,
  git,
  jujutsu,
  ripgrep,
  versionCheckHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "infinity";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "hydro-project";
    repo = "infinity";
    tag = "infinity-agent-cli-v${finalAttrs.version}";
    hash = "sha256-y6GmeED5F/DKHxG7cHTd9bki6QuDCIrlNxXrFbJxkUc=";
  };

  cargoHash = "sha256-3iYfEWOrVQoaSrWbdi1X4+QYqqbd1chVGDe4DImYG6Q=";

  # One workspace build. The daemon looks these names up on its PATH.
  cargoBuildFlags = [
    "--bin"
    "infinity"
    "--bin"
    "infinity-provider-bedrock"
    "--bin"
    "sandbox-local"
  ];

  # sandbox-local's build.rs runs `bwrap --version` and otherwise clones bubblewrap.
  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap ];

  # The sandbox server looks these up by name. Grep refuses to start without
  # rg, worktrees need git or jj, command execution needs bash, and the Linux
  # filesystem sandbox is bwrap. The daemon starts this program with `sh -c`,
  # so the wrapper has to be on sandbox-local itself.
  postInstall =
    let
      runtimePaths = [
        bash
        git
        jujutsu
        ripgrep
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap ];
    in
    ''
      wrapProgram $out/bin/sandbox-local \
        --prefix PATH : ${lib.makeBinPath runtimePaths}
    '';

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  # The provider has no --version flag. Its first stdout line is the socket
  # path the daemon reads. With RAP_EMBEDDED=1, sandbox-local's first stdout
  # line is {"port": N}. The sandbox builds a reqwest client before that line,
  # and this sandbox has no system trust store.
  installCheckPhase = ''
    runHook preInstallCheck

    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt

    stop_pid() {
      pid=$1
      kill "$pid" 2>/dev/null || true
      i=0
      while [ "$i" -lt 20 ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
          wait "$pid" 2>/dev/null || true
          return 0
        fi
        i=$((i + 1))
        sleep 0.1
      done
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    }

    wait_for_output() {
      file=$1
      pid=$2
      i=0
      while [ "$i" -lt 100 ]; do
        if [ -s "$file" ]; then
          return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
          return 1
        fi
        i=$((i + 1))
        sleep 0.1
      done
      return 1
    }

    show_logs() {
      label=$1
      dir=$2
      echo "$label did not produce the expected first line" >&2
      echo "--- stdout ---" >&2
      cat "$dir/out" >&2 || true
      echo "--- stderr ---" >&2
      cat "$dir/err" >&2 || true
    }

    provider_dir=$(mktemp -d)
    "$out/bin/infinity-provider-bedrock" > "$provider_dir/out" 2> "$provider_dir/err" &
    provider_pid=$!
    if wait_for_output "$provider_dir/out" "$provider_pid" \
      && head -n 1 "$provider_dir/out" | grep -Eq '^/.*/inf-provider-[0-9a-f]{12}\.sock$'; then
      rm -f "$(head -n 1 "$provider_dir/out")"
    else
      show_logs "infinity-provider-bedrock" "$provider_dir"
      stop_pid "$provider_pid"
      exit 1
    fi
    stop_pid "$provider_pid"

    "$out/bin/sandbox-local" --help | grep -q 'Local sandbox RAP server'

    sandbox_dir=$(mktemp -d)
    pushd "$sandbox_dir" >/dev/null
    RAP_EMBEDDED=1 "$out/bin/sandbox-local" > "$sandbox_dir/out" 2> "$sandbox_dir/err" &
    sandbox_pid=$!
    popd >/dev/null
    if ! wait_for_output "$sandbox_dir/out" "$sandbox_pid" \
      || ! head -n 1 "$sandbox_dir/out" | grep -Eq '^\{"port":[0-9]+\}$'; then
      show_logs "sandbox-local" "$sandbox_dir"
      stop_pid "$sandbox_pid"
      exit 1
    fi
    stop_pid "$sandbox_pid"

    runHook postInstallCheck
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Coding agent CLI with its Bedrock provider and local sandbox";
    homepage = "https://infinity.hydro.run/docs/infinity-code/overview/";
    changelog = "https://github.com/hydro-project/infinity/releases/tag/infinity-agent-cli-v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ malo ];
    mainProgram = "infinity";
    platforms = lib.platforms.unix;
  };
})
