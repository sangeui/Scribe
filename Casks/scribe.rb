cask "scribe" do
  version "0.1.0"
  sha256 "d8d0b7f0b6e6c6024cc1dac87199564093748c351e4857af1a197e72bb06b315"

  url "https://github.com/sangeui/Scribe/releases/download/v#{version}/Scribe.zip"
  name "Scribe"
  desc "Menu bar app turning AI coding token usage (Antigravity, Gemini, Claude Code) into classic literature writing"
  homepage "https://github.com/sangeui/Scribe"

  app "Scribe.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Scribe.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/Scribe",
    "~/Library/Preferences/local.scribe.plist",
  ]
end
