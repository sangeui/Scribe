cask "scribe" do
  version "0.2.0"
  sha256 "7166601964fdb9c745e10f25fd42f64b5e711e7d563f7bf32032a502886c41a9"

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
