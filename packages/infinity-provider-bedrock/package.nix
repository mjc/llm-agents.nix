{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "infinity-provider-bedrock";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "hydro-project";
    repo = "infinity";
    tag = "infinity-agent-cli-v${finalAttrs.version}";
    hash = "sha256-y6GmeED5F/DKHxG7cHTd9bki6QuDCIrlNxXrFbJxkUc=";
  };

  cargoHash = "sha256-3iYfEWOrVQoaSrWbdi1X4+QYqqbd1chVGDe4DImYG6Q=";

  cargoBuildFlags = [
    "--package"
    "infinity-provider-bedrock"
    "--bin"
    "infinity-provider-bedrock"
  ];

  doCheck = false;

  # The process prints a socket path and serves until the daemon stops it.
  # It has no --version flag, so the usual version hook cannot run.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/bin/infinity-provider-bedrock
    runHook postInstallCheck
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "AWS Bedrock model provider for Infinity coding agents";
    homepage = "https://infinity.hydro.run/docs/infinity-code/model-providers";
    changelog = "https://github.com/hydro-project/infinity/releases/tag/infinity-agent-cli-v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ malo ];
    mainProgram = "infinity-provider-bedrock";
    platforms = lib.platforms.unix;
  };
})
