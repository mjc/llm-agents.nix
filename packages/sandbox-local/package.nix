{
  lib,
  stdenv,
  flake,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  bash,
  bubblewrap,
  git,
  jujutsu,
  ripgrep,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "sandbox-local";
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
    "sandbox-local"
    "--bin"
    "sandbox-local"
  ];

  # build.rs runs `bwrap --version` and otherwise clones bubblewrap.
  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap ];

  # The server looks these up by name. Grep refuses to start without rg,
  # worktrees need git or jj, command execution needs bash, and the Linux
  # filesystem sandbox is bwrap.
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
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/sandbox-local --help | grep -q 'Local sandbox RAP server'
    runHook postInstallCheck
  '';

  passthru.category = "Sandboxing & Isolation";

  meta = {
    description = "Local sandbox server for Infinity coding agents";
    homepage = "https://infinity.hydro.run/docs/infinity-code/rap-servers";
    changelog = "https://github.com/hydro-project/infinity/releases/tag/infinity-agent-cli-v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ malo ];
    mainProgram = "sandbox-local";
    platforms = lib.platforms.unix;
  };
})
