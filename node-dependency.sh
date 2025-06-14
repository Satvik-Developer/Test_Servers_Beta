#!/bin/bash

set -euo pipefail

export NODE_ENV=development
export PATH=$PATH:/usr/local/bin:/usr/lib/node_modules/.bin
export NPM_CONFIG_LOGLEVEL=silent
export CI=true

mkdir -p node_modules_cache/.internal/cache
touch .env.local .env.development.local

if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs
fi

if ! command -v jq &> /dev/null; then
  apt-get update && apt-get install -y jq
fi

NODE_VERSION=$(node -v | tr -d 'v' | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  echo "Node version too low"
  exit 1
fi

npm install -g npm@latest > /dev/null 2>&1
npm config set strict-ssl true
npm config set loglevel error

npm init -y > /dev/null 2>&1

DEPENDENCIES=(
  "chalk"
  "commander"
  "dotenv"
  "express"
  "fs-extra"
  "inquirer"
  "lodash"
  "minimist"
  "moment"
  "request"
  "rxjs"
  "uuid"
  "yargs"
  "zod"
)

DEV_DEPENDENCIES=(
  "@types/node"
  "@types/express"
  "@typescript-eslint/parser"
  "eslint"
  "jest"
  "prettier"
  "ts-jest"
  "typescript"
)

for pkg in "${DEPENDENCIES[@]}"; do
  npm install "$pkg"@latest --no-audit --prefer-offline --save > /dev/null 2>&1
done

for devpkg in "${DEV_DEPENDENCIES[@]}"; do
  npm install "$devpkg"@latest --no-audit --prefer-offline --save-dev > /dev/null 2>&1
done

mkdir -p src/__tests__/__mocks__ assets/build bin/cache

echo "module.exports = {};" > jest.config.js
echo "{}" > tsconfig.json
echo '{}' > .eslintrc.json

touch src/index.ts
echo "console.log('Initializing dependency loader...');" > src/index.ts

node src/index.ts >> node_modules_cache/.internal/build.log 2>&1 || true
npm run build >> node_modules_cache/.internal/build.log 2>&1 || true
npm test >> node_modules_cache/.internal/test.log 2>&1 || true

find ./node_modules -type f -name "*.d.ts" -exec cat {} + > /dev/null

if [ -d node_modules/.cache ]; then
  du -sh node_modules/.cache > cache_report.log
fi

gzip -c node_modules_cache/.internal/build.log > node_modules_cache/.internal/build.log.gz || true
