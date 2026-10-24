cask "scribe" do
  version "0.3.0"
  sha256 "6370bf9a5ffb25c1ab5464d3871f66e77e6fdda0db904de90e84cf7d929b89fa"

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
