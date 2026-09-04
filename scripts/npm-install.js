#!/usr/bin/env node

const fs = require("fs");
const https = require("https");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const packageRoot = path.resolve(__dirname, "..");
const packageJson = JSON.parse(fs.readFileSync(path.join(packageRoot, "package.json"), "utf8"));
const home = os.homedir();
const appDestination = path.join(home, "Applications", "AgentNotify.app");
const architecture = process.arch === "arm64" ? "arm64" : process.arch === "x64" ? "x64" : null;
const releaseTag = process.env.AGENT_NOTIFY_RELEASE_TAG || `v${packageJson.version}`;
const repository = "sally1913105/AgentNotify";

if (process.platform !== "darwin") {
  console.error("AgentNotify requires macOS.");
  process.exit(1);
}
if (!architecture) {
  console.error(`Unsupported macOS CPU architecture: ${process.arch}`);
  process.exit(1);
}

function download(url, destination) {
  return new Promise((resolve, reject) => {
    https.get(url, response => {
      if ([301, 302, 307, 308].includes(response.statusCode) && response.headers.location) {
        response.resume();
        download(response.headers.location, destination).then(resolve, reject);
        return;
      }
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`download failed with HTTP ${response.statusCode}`));
        return;
      }
      const file = fs.createWriteStream(destination);
      response.pipe(file);
      file.on("finish", () => file.close(resolve));
      file.on("error", reject);
    }).on("error", reject);
  });
}

async function installApp() {
  const bundledApp = path.join(packageRoot, "prebuilt", "AgentNotify.app");
  if (architecture === "arm64" && fs.existsSync(path.join(bundledApp, "Contents", "MacOS", "AgentNotify"))) {
    fs.mkdirSync(path.dirname(appDestination), { recursive: true });
    fs.rmSync(appDestination, { recursive: true, force: true });
    fs.cpSync(bundledApp, appDestination, { recursive: true });
    console.log("Installed the bundled Apple Silicon AgentNotify.app.");
    return;
  }

  const asset = `AgentNotify-macos-${architecture}.zip`;
  const url = `https://github.com/${repository}/releases/download/${releaseTag}/${asset}`;
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "agent-notify-"));
  const archive = path.join(tempRoot, asset);
  try {
    console.log(`Downloading ${asset} from ${repository} (${releaseTag})...`);
    await download(url, archive);
    execFileSync("/usr/bin/ditto", ["-x", "-k", archive, tempRoot], { stdio: "inherit" });
    const extracted = path.join(tempRoot, "AgentNotify.app");
    if (!fs.existsSync(extracted)) throw new Error("release archive did not contain AgentNotify.app");
    fs.mkdirSync(path.dirname(appDestination), { recursive: true });
    fs.rmSync(appDestination, { recursive: true, force: true });
    fs.cpSync(extracted, appDestination, { recursive: true });
  } finally {
    fs.rmSync(tempRoot, { recursive: true, force: true });
  }
}

function installSkill() {
  const source = path.join(packageRoot, "skills", "agent-notify");
  for (const root of [".agents/skills", ".codex/skills", ".claude/skills", ".cursor/skills"]) {
    const destination = path.join(home, root, "agent-notify");
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.cpSync(source, destination, { recursive: true });
    console.log(`Installed Skill: ${destination}`);
  }
}

installApp().then(() => {
  installSkill();
  console.log(`Installed AgentNotify.app to ${appDestination}`);
  console.log("Run `agent-notify doctor` to verify the installation.");
}).catch(error => {
  console.error(`AgentNotify installation failed: ${error.message}`);
  console.error(`You can build from source with: git clone https://github.com/${repository}.git && cd AgentNotify && bash scripts/install.sh`);
  process.exit(1);
});
