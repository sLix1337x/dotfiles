#!/usr/bin/env node
// Runs a plugin's mode hook while the plugin itself stays disabled, so the mode
// prompt still loads but the plugin's never-used skills/agents never register.
// Resolves the newest version dir so a plugin auto-update can't silently break this.
//
//   node mode-hook.js ponytail hooks ponytail-activate.js
//   node mode-hook.js caveman src hooks caveman-activate.js
//
// Exits 0 silently if the plugin is gone - a missing mode must never block a session.
const { existsSync, readdirSync, statSync } = require("fs");
const { join } = require("path");

const [plugin, ...rel] = process.argv.slice(2);
const base = join(
  process.env.USERPROFILE || process.env.HOME,
  ".claude", "plugins", "cache", plugin, plugin,
);

let root;
try {
  const newest = readdirSync(base)
    .map((d) => [d, statSync(join(base, d)).mtimeMs])
    .sort((a, b) => b[1] - a[1])[0];
  if (!newest) process.exit(0);
  root = join(base, newest[0]);
} catch {
  process.exit(0);
}

const script = join(root, ...rel);
if (!existsSync(script)) process.exit(0);

process.env.CLAUDE_PLUGIN_ROOT = root;
require(script);
