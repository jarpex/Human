#!/usr/bin/env bash
set -euo pipefail

CASK_FILE="$1"
VERSION="$2"
SHA="$3"

mkdir -p "$(dirname "$CASK_FILE")"

cat << EOF > "$CASK_FILE"
cask "human" do
  version "${VERSION}"
  sha256 "${SHA}"

  url "https://github.com/jarpex/Human/releases/download/v#{version}/Human.zip"
  name "Human"
  desc "Floating webcam preview window"
  homepage "https://github.com/jarpex/Human"

  depends_on macos: :sonoma

  app "Human.app"

  zap trash: "~/Library/Saved Application State/com.jarpex.human.savedState"
end
EOF
