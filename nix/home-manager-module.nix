# Home Manager module for voxtype
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.voxtype;
  tomlFormat = pkgs.formats.toml { };
  
  # Runtime dependencies for output backends
  runtimeDeps = with pkgs; [
    wtype        # Wayland typing (preferred)
    wl-clipboard # Clipboard fallback (wl-copy)
  ];
in {
  options.programs.voxtype = {
    enable = lib.mkEnableOption "voxtype voice-to-text";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.voxtype or null;
      defaultText = lib.literalExpression "pkgs.voxtype";
      description = "The voxtype package to use.";
    };

    model = lib.mkOption {
      type = lib.types.enum [
        "tiny.en" "base.en" "small.en" "medium.en"
        "tiny" "base" "small" "medium"
        "large-v3" "large-v3-turbo"
      ];
      default = "base.en";
      description = "Whisper model to use for transcription.";
    };

    modelPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Pre-downloaded model package. If null, voxtype will download
        the model on first run via 'voxtype setup --download'.
      '';
    };

    enableSystemdService = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the systemd user service.";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          hotkey = {
            key = "SCROLLLOCK";
            mode = "hold";  # or "toggle"
          };
          audio = {
            device = "default";
            sample_rate = 16000;
          };
          whisper = {
            model = "base.en";
            language = "en";
          };
          output = {
            mode = "type";  # "type", "clipboard", or "paste"
            fallback_to_clipboard = true;
          };
        }
      '';
      description = ''
        Configuration for voxtype. See https://github.com/peteonrails/voxtype
        for all available options.
      '';
    };

    hotkey = {
      key = lib.mkOption {
        type = lib.types.str;
        default = "SCROLLLOCK";
        description = "Key to use for push-to-talk.";
      };

      mode = lib.mkOption {
        type = lib.types.enum [ "push_to_talk" "toggle" ];
        default = "push_to_talk";
        description = "Whether to hold the key (push_to_talk) or toggle on/off.";
      };

      modifiers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "LEFTCTRL" "LEFTALT" ];
        description = "Modifier keys required with the hotkey.";
      };

      # For compositor keybindings (recommended)
      useCompositorBindings = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to use compositor keybindings instead of built-in hotkey.
          When true, disables the built-in hotkey. Configure your compositor
          to call 'voxtype record start' and 'voxtype record stop'.
        '';
      };
    };

    output = {
      mode = lib.mkOption {
        type = lib.types.enum [ "type" "clipboard" "paste" ];
        default = "type";
        description = ''
          How to output transcribed text:
          - type: Use wtype/ydotool to type the text
          - clipboard: Copy to clipboard only
          - paste: Copy to clipboard and simulate Ctrl+V
        '';
      };

      typeDelayMs = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Delay between keystrokes in ms (increase if characters are dropped).";
      };

      autoSubmit = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Send Enter after transcription (useful for chat apps).";
      };
    };

    audio = {
      device = lib.mkOption {
        type = lib.types.str;
        default = "default";
        description = "Audio input device (use 'pactl list sources short' to list).";
      };

      feedback = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable audio feedback sounds when recording starts/stops.";
        };

        theme = lib.mkOption {
          type = lib.types.str;
          default = "default";
          description = "Audio feedback theme: default, subtle, mechanical, or path to custom dir.";
        };

        volume = lib.mkOption {
          type = lib.types.float;
          default = 0.7;
          description = "Feedback sound volume (0.0 to 1.0).";
        };
      };
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra configuration to append to config.toml.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Generate config file
    xdg.configFile."voxtype/config.toml" = {
      source = tomlFormat.generate "voxtype-config" (lib.recursiveUpdate {
        # State file for toggle mode and Waybar/polybar integration
        state_file = "auto";

        hotkey = {
          key = cfg.hotkey.key;
          mode = cfg.hotkey.mode;
          modifiers = cfg.hotkey.modifiers;
          enabled = !cfg.hotkey.useCompositorBindings;
        };

        audio = {
          device = cfg.audio.device;
          sample_rate = 16000;
          max_duration_secs = 60;
        } // lib.optionalAttrs cfg.audio.feedback.enable {
          feedback = {
            enabled = true;
            theme = cfg.audio.feedback.theme;
            volume = cfg.audio.feedback.volume;
          };
        };

        whisper = {
          model = cfg.model;
          language = "en";
        };

        output = {
          mode = cfg.output.mode;
          fallback_to_clipboard = true;
          type_delay_ms = cfg.output.typeDelayMs;
          auto_submit = cfg.output.autoSubmit;
        };
      } cfg.settings);
    };

    # Systemd user service
    systemd.user.services.voxtype = lib.mkIf cfg.enableSystemdService {
      Unit = {
        Description = "Voxtype voice-to-text daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${cfg.package}/bin/voxtype daemon";
        Restart = "on-failure";
        RestartSec = 5;
        # Ensure output backends (wtype, wl-copy) are in PATH
        Environment = "PATH=${lib.makeBinPath runtimeDeps}:/run/current-system/sw/bin";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
