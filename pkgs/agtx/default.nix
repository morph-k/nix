{
  rustPlatform,
  agtx-src,
  git,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "agtx";
  version = "0.1.0";
  src = agtx-src;
  cargoLock = {
    lockFile = "${agtx-src}/Cargo.lock";
  };
  # Upstream test suite (db_tests/mcp_tests/git_tests) doesn't compile at the
  # pinned rev; the binary itself builds fine, so skip the check phase.
  doCheck = false;
  nativeCheckInputs = [git];
  meta = {
    description = "Terminal-native kanban board for managing coding agents";
    mainProgram = "agtx";
  };
}
