{
  description = "Push-to-talk voice-to-text for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Whisper models
        whisperModels = import ./nix/whisper-models.nix { inherit pkgs; };

        # Common build inputs for all variants
        commonNativeBuildInputs = with pkgs; [
          cmake
          pkg-config
          clang
          llvmPackages.libclang
          git  # Required by whisper.cpp cmake
        ];

        commonBuildInputs = with pkgs; [
          alsa-lib
          openssl
        ];

        # Base derivation for voxtype
        mkVoxtype = { pname ? "voxtype", features ? [], extraNativeBuildInputs ? [], extraBuildInputs ? [], extraEnv ? {} }:
          pkgs.rustPlatform.buildRustPackage ({
            inherit pname;
            version = "0.4.9";

            src = pkgs.lib.cleanSource ./.;
            cargoLock.lockFile = ./Cargo.lock;

            nativeBuildInputs = commonNativeBuildInputs ++ extraNativeBuildInputs;
            buildInputs = commonBuildInputs ++ extraBuildInputs;

            # Required for whisper-rs bindgen
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

            # Build with specified features
            buildFeatures = features;

            # Ensure reproducible builds targeting AVX2-capable CPUs (x86-64-v3)
            # This matches the portable AVX2 binaries we ship for other distros
            RUSTFLAGS = pkgs.lib.optionalString (system == "x86_64-linux")
              "-C target-cpu=x86-64-v3";

            # whisper.cpp cmake needs some help in sandbox
            preBuild = ''
              export CMAKE_BUILD_PARALLEL_LEVEL=$NIX_BUILD_CORES
            '';

            # Install shell completions and systemd service
            postInstall = ''
              # Shell completions
              install -Dm644 packaging/completions/voxtype.bash \
                $out/share/bash-completion/completions/voxtype
              install -Dm644 packaging/completions/voxtype.zsh \
                $out/share/zsh/site-functions/_voxtype
              install -Dm644 packaging/completions/voxtype.fish \
                $out/share/fish/vendor_completions.d/voxtype.fish

              # Systemd user service
              install -Dm644 packaging/systemd/voxtype.service \
                $out/lib/systemd/user/voxtype.service

              # Default config
              install -Dm644 config/default.toml \
                $out/share/voxtype/default-config.toml
            '';

            meta = with pkgs.lib; {
              description = "Push-to-talk voice-to-text for Linux";
              longDescription = ''
                Voxtype is a push-to-talk voice-to-text daemon for Linux.
                Hold a hotkey while speaking, release to transcribe and output
                text at your cursor position. Fully offline using whisper.cpp.
              '';
              homepage = "https://voxtype.io";
              license = licenses.mit;
              maintainers = []; # Add NixOS maintainers when upstreaming
              platforms = [ "x86_64-linux" "aarch64-linux" ];
              mainProgram = "voxtype";
            };
          } // extraEnv);

      in {
        packages = {
          # Default: CPU-only build (AVX2 baseline on x86_64)
          default = mkVoxtype {};

          # Alias for clarity
          cpu = mkVoxtype {};

          # Vulkan GPU acceleration (works on AMD, NVIDIA, Intel)
          vulkan = let
            vulkanPkg = mkVoxtype {
              pname = "voxtype-vulkan";
              features = [ "gpu-vulkan" ];
              extraNativeBuildInputs = with pkgs; [
                shaderc
                vulkan-headers
                vulkan-loader
              ];
              extraBuildInputs = with pkgs; [
                vulkan-headers
                vulkan-loader
              ];
            };
          in vulkanPkg.overrideAttrs (old: {
            # Help cmake find Vulkan SDK components
            preBuild = (old.preBuild or "") + ''
              export CMAKE_BUILD_PARALLEL_LEVEL=$NIX_BUILD_CORES
              export VULKAN_SDK="${pkgs.vulkan-loader}"
              export Vulkan_INCLUDE_DIR="${pkgs.vulkan-headers}/include"
              export Vulkan_LIBRARY="${pkgs.vulkan-loader}/lib/libvulkan.so"
            '';
          });

          # ROCm/HIP GPU acceleration (AMD GPUs)
          # Note: This requires ROCm to be available in nixpkgs
          rocm = let
            rocmPkg = mkVoxtype {
              pname = "voxtype-rocm";
              features = [ "gpu-hipblas" ];
              extraNativeBuildInputs = with pkgs; [
                rocmPackages.clr
                rocmPackages.hipblas
                rocmPackages.rocblas
              ];
              extraBuildInputs = with pkgs; [
                rocmPackages.clr
                rocmPackages.hipblas
                rocmPackages.rocblas
              ];
            };
          in rocmPkg.overrideAttrs (old: {
            preBuild = (old.preBuild or "") + ''
              export CMAKE_BUILD_PARALLEL_LEVEL=$NIX_BUILD_CORES
              export HIP_PATH="${pkgs.rocmPackages.clr}"
              export ROCM_PATH="${pkgs.rocmPackages.clr}"
            '';
          });

          # Whisper models as packages (for pre-downloading)
          whisper-model-tiny-en = whisperModels.tiny-en;
          whisper-model-base-en = whisperModels.base-en;
          whisper-model-small-en = whisperModels.small-en;
          whisper-model-medium-en = whisperModels.medium-en;
          whisper-model-large-v3 = whisperModels.large-v3;
          whisper-model-large-v3-turbo = whisperModels.large-v3-turbo;
        };

        # Expose models for use in modules
        inherit whisperModels;

        # Development shell with all dependencies
        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];

          packages = with pkgs; [
            rust-analyzer
            rustfmt
            clippy
            # Optional runtime deps for testing
            wtype
            ydotool
            wl-clipboard
          ];
        };
      }) // {
        # NixOS module for system-level configuration
        nixosModules.default = { config, lib, pkgs, ... }:
          let
            cfg = config.services.voxtype;
          in {
            options.services.voxtype = {
              enable = lib.mkEnableOption "voxtype voice-to-text service";

              package = lib.mkOption {
                type = lib.types.package;
                default = self.packages.${pkgs.system}.default;
                defaultText = lib.literalExpression "voxtype.packages.\${system}.default";
                description = "The voxtype package to use.";
              };

              typingBackend = lib.mkOption {
                type = lib.types.enum [ "wtype" "ydotool" "auto" ];
                default = "auto";
                description = ''
                  Backend for text output:
                  - wtype: Wayland virtual keyboard (recommended)
                  - ydotool: Uses uinput, works on X11 and Wayland
                  - auto: Install both, let voxtype choose
                '';
              };

              enableUinput = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = ''
                  Enable uinput kernel module.
                  Required for ydotool and built-in hotkey support.
                '';
              };

              inputGroupUsers = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [ "kevin" ];
                description = ''
                  Users to add to the input group for evdev hotkey access.
                  Not needed if using compositor keybindings.
                '';
              };
            };

            config = lib.mkIf cfg.enable {
              environment.systemPackages = with pkgs; [
                cfg.package
                wl-clipboard
              ] ++ lib.optional (cfg.typingBackend == "wtype" || cfg.typingBackend == "auto") wtype
                ++ lib.optional (cfg.typingBackend == "ydotool" || cfg.typingBackend == "auto") ydotool;

              hardware.uinput.enable = lib.mkIf cfg.enableUinput true;

              users.users = lib.mkIf (cfg.inputGroupUsers != [ ]) (
                lib.genAttrs cfg.inputGroupUsers (user: {
                  extraGroups = [ "input" ];
                })
              );

              systemd.user.services.ydotool = lib.mkIf (cfg.typingBackend == "ydotool" || cfg.typingBackend == "auto") {
                description = "ydotool daemon";
                wantedBy = [ "graphical-session.target" ];
                partOf = [ "graphical-session.target" ];
                serviceConfig = {
                  ExecStart = "${pkgs.ydotool}/bin/ydotoold";
                  Restart = "on-failure";
                };
              };
            };
          };

        # Home Manager module
        homeModules.default = import ./nix/home-manager-module.nix;
      };
}
