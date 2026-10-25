cask "scribe" do
  version "0.6.3"
  sha256 "8c85c92458104a0088307f950f6d61e461bcf76ec0684f2e09568af16e87aeb3"

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
