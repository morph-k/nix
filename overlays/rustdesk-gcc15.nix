# Fix rustdesk's vendored webm-sys failing to compile under GCC 15
# (missing <cstdint> include). Applied on hosts that build rustdesk from source.
_final: prev: {
  rustdesk = prev.rustdesk.overrideAttrs (old: {
    preBuild =
      (old.preBuild or "")
      + ''
        # Patch webm-sys for GCC 15 compatibility
        echo "=== Patching webm-sys C++ files for GCC 15 ==="

        # The vendor directory is at /build/rustdesk-1.4.4-vendor/
        if [ -d "/build/rustdesk-1.4.4-vendor/webm-sys-1.0.4" ]; then
          echo "Found webm-sys-1.0.4 in vendor directory, patching..."
          find /build/rustdesk-1.4.4-vendor/webm-sys-1.0.4 -type f -name "*.cc" -print -exec sed -i '1i#include <cstdint>' {} \;
          find /build/rustdesk-1.4.4-vendor/webm-sys-1.0.4 -type f -name "*.h" -print -exec sed -i '1i#include <cstdint>' {} \; || true
          echo "Patching complete!"
        else
          echo "WARNING: webm-sys-1.0.4 not found in vendor directory"
        fi
      '';
  });
}
