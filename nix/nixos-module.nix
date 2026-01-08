# NixOS module for voxtype
{ config, lib, pkgs, ... }:

let
  cfg = config.services.voxtype;
in {
  options.services.voxtype = {
    enable = lib.mkEnableOption "voxtype voice-to-text service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.voxtype or null;
      defaultText = lib.literalExpression "pkgs.voxtype";
      description = "The voxtype package to use.";
    };

    # Runtime dependencies
    typingBackend = lib.mkOption {
      type = lib.types.enum [ "wtype" "ydotool" "auto" ];
      default = "auto";
      description = ''
        Backend for text output:
        - wtype: Wayland virtual keyboard (recommended, best Unicode/CJK support)
        - ydotool: Uses uinput, works on X11 and Wayland
        - auto: Install both, let voxtype choose
      '';
    };

    # Model management
    models = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [
        "tiny.en" "base.en" "small.en" "medium.en"
        "tiny" "base" "small" "medium"
        "large-v3" "large-v3-turbo"
      ]);
      default = [ "base.en" ];
      description = "Whisper models to pre-download.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "base.en";
      description = "Default whisper model for transcription.";
    };

    # System-level configuration
    enableUinput = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable uinput kernel module and configure udev rules.
        Required for ydotool backend and built-in hotkey support.
      '';
    };

    # Users who can use voxtype's evdev hotkey feature
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
    # Install voxtype and typing backends
    environment.systemPackages = with pkgs; [
      cfg.package
      wl-clipboard  # Clipboard fallback
    ] ++ lib.optional (cfg.typingBackend == "wtype" || cfg.typingBackend == "auto") wtype
      ++ lib.optional (cfg.typingBackend == "ydotool" || cfg.typingBackend == "auto") ydotool;

    # Enable uinput for ydotool/evdev
    hardware.uinput.enable = lib.mkIf cfg.enableUinput true;

    # Add users to input group
    users.users = lib.mkIf (cfg.inputGroupUsers != [ ]) (
      lib.genAttrs cfg.inputGroupUsers (user: {
        extraGroups = [ "input" ];
      })
    );

    # Ensure ydotool daemon is available if using ydotool
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
}
