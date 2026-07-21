# Homebrew cask for Wakehold. Copy this into your tap (homebrew-wakehold/Casks/wakehold.rb) and
# bump version, url, and sha256 for each release. The binary stanza puts the wakehold CLI on PATH.
cask "wakehold" do
  version "0.1.0"
  sha256 "REPLACE_WITH_THE_ZIP_SHA256"

  url "https://github.com/KhaledSaeed18/wakehold/releases/download/v#{version}/Wakehold.zip"
  name "Wakehold"
  desc "Session-aware wake controller for macOS"
  homepage "https://github.com/KhaledSaeed18/wakehold"

  depends_on macos: ">= :sonoma"

  app "Wakehold.app"
  binary "#{appdir}/Wakehold.app/Contents/Helpers/wakehold"

  zap trash: [
    "~/Library/Application Support/Wakehold",
  ]
end
