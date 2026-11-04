{
  lib,
  flake,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  python3,
  versionCheckHook,
  webSocketPort ? 8080,
}:

buildNpmPackage (finalAttrs: {
  pname = "infinity-webui";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "hydro-project";
    repo = "infinity";
    tag = "infinity-agent-cli-v${finalAttrs.version}";
    hash = "sha256-y6GmeED5F/DKHxG7cHTd9bki6QuDCIrlNxXrFbJxkUc=";
  };

  uiNpmDeps = fetchNpmDeps {
    inherit (finalAttrs) version src;
    sourceRoot = "source/infinity-ui";
    hash = "sha256-h9qIb554wR17T3kFEG435bbiVfCnIXnSHK5zxG+ziH0=";
    fetcherVersion = 2;
  };

  npmRoot = "infinity-web";
  npmDepsFetcherVersion = 2;
  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) version src;
    sourceRoot = "source/infinity-web";
    hash = "sha256-vdDnvkSvpnkUh4Ix2XuWwpT7CNqlbkXgKdR1lPyVLn8=";
    fetcherVersion = 2;
  };

  env.VITE_WS_PORT = toString webSocketPort;

  nativeBuildInputs = [ python3 ];

  preBuild = ''
    cp -r ${finalAttrs.uiNpmDeps} "$TMPDIR/infinity-ui-npm-cache"
    chmod -R u+w "$TMPDIR/infinity-ui-npm-cache"
    npm ci --prefix infinity-ui --offline --cache "$TMPDIR/infinity-ui-npm-cache"
  '';

  dontNpmBuild = true;
  buildPhase = ''
    runHook preBuild

    npm --prefix infinity-web run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -d $out/share/infinity-web $out/bin
    cp -r infinity-web/dist/. $out/share/infinity-web/

    cat > $out/bin/infinity-webui <<'EOF'
    #!/bin/sh
    case "''${1-}" in
      --version)
        echo "@version@"
        exit 0
        ;;
      --help|-h)
        cat <<'HELP'
    Infinity Web UI server for Infinity coding agents.

    Usage: infinity-webui [--help|--version]

    Serves the UI on 127.0.0.1:4173 by default. Configure the HTTP listener
    with INFINITY_WEBUI_BIND and INFINITY_WEBUI_PORT. Set the webSocketPort Nix
    argument to match the daemon port (default 8080).
    HELP
        exit 0
        ;;
      "")
        ;;
      *)
        echo "infinity-webui: unexpected argument: $1" >&2
        echo "Run 'infinity-webui --help' for usage." >&2
        exit 2
        ;;
    esac

    port="''${INFINITY_WEBUI_PORT:-4173}"
    bind="''${INFINITY_WEBUI_BIND:-127.0.0.1}"
    exec @python@/bin/python3 -m http.server "$port" --bind "$bind" \
      --directory "@out@/share/infinity-web" "$@"
    EOF
    substituteInPlace $out/bin/infinity-webui \
      --replace-fail @version@ ${finalAttrs.version} \
      --replace-fail @python@ ${python3} \
      --replace-fail @out@ $out
    chmod +x $out/bin/infinity-webui

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Standalone web UI for Infinity coding agents";
    homepage = "https://infinity.hydro.run/docs/infinity-code/overview/";
    changelog = "https://github.com/hydro-project/infinity/releases/tag/infinity-agent-cli-v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ malo ];
    mainProgram = "infinity-webui";
    platforms = lib.platforms.unix;
  };
})
