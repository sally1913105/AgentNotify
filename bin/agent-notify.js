#!/usr/bin/env node

const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const app = path.join(os.homedir(), "Applications", "AgentNotify.app");
const executable = path.join(app, "Contents", "MacOS", "AgentNotify");
const args = process.argv.slice(2);

if (!require("fs").existsSync(executable)) {
  console.error("AgentNotify.app is not installed. Re-run npm install for this package.");
  process.exit(1);
}

const result = spawnSync(executable, args, { stdio: "inherit" });
if (result.error) {
  console.error(`agent-notify: ${result.error.message}`);
  process.exit(1);
}
process.exit(result.status === null ? 1 : result.status);
