# Whisper model definitions for voxtype
# Models are fetched from Hugging Face: https://huggingface.co/ggerganov/whisper.cpp
{ pkgs }:

let
  baseUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

  # Helper to create a model derivation
  mkModel = { name, file, hash, size ? "unknown" }:
    pkgs.fetchurl {
      url = "${baseUrl}/${file}";
      sha256 = hash;
      name = "whisper-model-${name}";
      meta = {
        description = "Whisper ${name} model for speech-to-text";
        homepage = "https://huggingface.co/ggerganov/whisper.cpp";
        license = pkgs.lib.licenses.mit;
      };
    };

in {
  # Model definitions with their hashes
  # English-only models (faster, more accurate for English)
  tiny-en = mkModel {
    name = "tiny.en";
    file = "ggml-tiny.en.bin";
    hash = "sha256-KNKN/AFBLkqDwLf+6N/TfZxiNqOuFPBCqAC49sPc1gE=";
    size = "77.7 MB";
  };

  base-en = mkModel {
    name = "base.en";
    file = "ggml-base.en.bin";
    hash = "sha256-k8t5Zv8cxeaAtIWXsnKTkvNLjFJp/xPs4hZySCh7WjU=";
    size = "148 MB";
  };

  small-en = mkModel {
    name = "small.en";
    file = "ggml-small.en.bin";
    hash = "sha256-sN0GHNr8LycJt+lbkPwGcWS8xZGlJSLNzJYUkPBkTyc=";
    size = "488 MB";
  };

  medium-en = mkModel {
    name = "medium.en";
    file = "ggml-medium.en.bin";
    hash = "sha256-X0LiDgDNQOZ+f8K0IlA6DZQ2vCh7cO0DYKK6iRTvxDw=";
    size = "1.53 GB";
  };

  # Multilingual models
  tiny = mkModel {
    name = "tiny";
    file = "ggml-tiny.bin";
    hash = "sha256-x9PpIX5E3sSlVhxR6rEfuFv5EKf/JdF/M4WXy5Oxl24=";
    size = "77.7 MB";
  };

  base = mkModel {
    name = "base";
    file = "ggml-base.bin";
    hash = "sha256-InQHHwPg2WDGN8H3Qr/0g2CvuRU6S6fP0z4K7B5xBvk=";
    size = "148 MB";
  };

  small = mkModel {
    name = "small";
    file = "ggml-small.bin";
    hash = "sha256-c4e/sCy1bUmE9ZJQ6RR+eEwDl1dHSyvQTATKQDPvqVA=";
    size = "488 MB";
  };

  medium = mkModel {
    name = "medium";
    file = "ggml-medium.bin";
    hash = "sha256-B7xxN1cRNzFqB4i6yLAl4g2EbZmgFm4i8jlUH4U3N0M=";
    size = "1.53 GB";
  };

  large-v3 = mkModel {
    name = "large-v3";
    file = "ggml-large-v3.bin";
    hash = "sha256-vRCGxDYqhN0LYWmBCrgBEzVpQ7nfFNeStAi1e3TMujY=";
    size = "3.1 GB";
  };

  large-v3-turbo = mkModel {
    name = "large-v3-turbo";
    file = "ggml-large-v3-turbo.bin";
    hash = "sha256-bq1GHTdYl9SFvFlllSsICSfMhPLq3QnPqBzC5qD3cYg=";
    size = "1.62 GB";
  };

  # Quantized models (smaller, slightly less accurate)
  base-en-q8 = mkModel {
    name = "base.en-q8_0";
    file = "ggml-base.en-q8_0.bin";
    hash = "sha256-1hNFXCFaGv/x/yzALzOqy7I1xLJQgEMQT6ExwMfW6DY=";
    size = "81.8 MB";
  };

  large-v3-turbo-q5 = mkModel {
    name = "large-v3-turbo-q5_0";
    file = "ggml-large-v3-turbo-q5_0.bin";
    hash = "sha256-Kw4C1Z4PNvB1sMjPsCi5ELz/kOdlLp+FuB5wPyg+5lQ=";
    size = "574 MB";
  };

  # Model metadata for documentation/selection
  modelInfo = {
    tiny-en = { size = "77.7 MB"; accuracy = "low"; speed = "fastest"; languages = "english"; };
    base-en = { size = "148 MB"; accuracy = "good"; speed = "fast"; languages = "english"; };
    small-en = { size = "488 MB"; accuracy = "better"; speed = "medium"; languages = "english"; };
    medium-en = { size = "1.53 GB"; accuracy = "high"; speed = "slow"; languages = "english"; };
    large-v3 = { size = "3.1 GB"; accuracy = "best"; speed = "slowest"; languages = "99 languages"; };
    large-v3-turbo = { size = "1.62 GB"; accuracy = "best"; speed = "fast"; languages = "99 languages"; };
  };
}
