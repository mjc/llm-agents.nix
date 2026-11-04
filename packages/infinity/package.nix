{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  openssl,
  pkg-config,
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

  cargoBuildFlags = [
    "--package"
    "infinity-agent-cli"
    "--bin"
    "infinity"
  ];

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Coding agent CLI built on the Infinity concurrent agent runtime";
    homepage = "https://infinity.hydro.run/docs/infinity-code/overview/";
    changelog = "https://github.com/hydro-project/infinity/releases/tag/infinity-agent-cli-v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ malo ];
    mainProgram = "infinity";
    platforms = lib.platforms.unix;
  };
})
