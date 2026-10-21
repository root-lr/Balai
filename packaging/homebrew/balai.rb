# Cask Homebrew de Balai. La copie publiée vit dans le tap root-lr/homebrew-balai :
# la CI y met à jour `version` et `sha256` à chaque release (voir .github/workflows/build.yml).
cask "balai" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/root-lr/Balai/releases/download/v#{version}/Balai.dmg"
  name "Balai"
  desc "Free and open-source disk cleaner and app uninstaller"
  homepage "https://github.com/root-lr/Balai"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Balai.app"

  # L'app n'est pas encore notarisée : on retire la quarantaine pour qu'elle s'ouvre normalement.
  postflight_steps do
    if_path_exists "{{appdir}}/Balai.app" do
      run "/usr/bin/xattr",
          args: ["-dr", "com.apple.quarantine", "{{appdir}}/Balai.app"]
    end
  end

  uninstall quit: "io.github.root-lr.Balai"

  zap trash: [
    "~/Library/Caches/io.github.root-lr.Balai",
    "~/Library/Preferences/io.github.root-lr.Balai.plist",
    "~/Library/Saved Application State/io.github.root-lr.Balai.savedState",
  ]
end
