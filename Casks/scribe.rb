cask "scribe" do
  version "0.5.1"
  sha256 "9981a2e104cf362ce4d6c49da3c03801efadb510d75aadee25e701010210f9a8"

  url "https://github.com/sangeui/Scribe/releases/download/v#{version}/Scribe.zip"
  name "Scribe"
  desc "Menu bar app turning AI coding token usage (Antigravity, Gemini, Claude Code) into classic literature writing"
  homepage "https://github.com/sangeui/Scribe"

  app "Scribe.app"

  uninstall quit: "local.scribe"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Scribe.app"],
                   sudo: false
    system_command "/usr/bin/open",
                   args: ["-a", "#{appdir}/Scribe.app"],
                   sudo: false,
                   must_succeed: false
  end

  zap trash: [
    "~/Library/Application Support/Scribe",
    "~/Library/Preferences/local.scribe.plist",
  ]
end
