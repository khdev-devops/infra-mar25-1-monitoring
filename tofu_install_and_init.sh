#!/bin/bash
set -e

CACHE_DIR="$HOME/.terraform.d/plugin-cache"
CONFIG_FILE="$HOME/.tofurc"
AWS_CACHE_PATH="$CACHE_DIR/registry.opentofu.org/hashicorp/aws"

echo "🔍 Kontroll av ledigt utrymme..."

# Kolla hur mycket som används i /home/cloudshell-user
USED_PERCENT=$(df /home/cloudshell-user | awk 'NR==2 {gsub(/%/, "", $5); print $5}')

if [ "$USED_PERCENT" -ge 90 ]; then
  echo "⚠️  Din CloudShell-disk är $USED_PERCENT% full. Rensar plugin-cache..."
  rm -rf $CACHE_DIR || true
  echo "✅ Rensat OpenTofu plugin-cache."
else
  echo "✅ Diskanvändning OK ($USED_PERCENT%)."
fi

# Ensure the cache directory exists
if [ ! -d "$CACHE_DIR" ]; then
  echo "📂 Creating OpenTofu provider cache directory..."
  mkdir -p "$CACHE_DIR"
fi

echo "⚙️ Konfigurerar OpenTofu provider-cache..."
cat <<EOF > "$CONFIG_FILE"
plugin_cache_dir = "$CACHE_DIR"
EOF

echo "⬇️ Installerar OpenTofu..."

curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
chmod +x install-opentofu.sh
./install-opentofu.sh --install-method standalone --skip-verify
rm install-opentofu.sh


echo "🚀 Kör tofu init..."
INIT_LOG="$(mktemp)"
if tofu init 2>&1 | tee "$INIT_LOG"; then
  echo "✅ tofu init lyckades"
else
  if grep -q "no space left on device" "$INIT_LOG"; then
    echo "❌ Detekterat 'no space left on device'"
    if [ -d "$AWS_CACHE_PATH" ]; then
      echo "🧹 Rensar AWS provider-cache..."
      rm -rf "$AWS_CACHE_PATH"
    fi
    echo "🔁 Kör tofu init igen..."
    tofu init
  else
    echo "⚠️ tofu init misslyckades av annan orsak"
    exit 1
  fi
fi