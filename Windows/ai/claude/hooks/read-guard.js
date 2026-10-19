#!/usr/bin/env node
// PreToolUse(Read) hook: deny whole-file reads of big text files and junk paths,
// so the "ranged Read only" rule is enforced mechanically instead of by prompt.
// Self-check: node read-guard.js --selftest
const fs = require('fs');

const MAX_LINES = 600;           // whole-file reads above this need offset/limit
const MAX_BYTES = 60000;
const JUNK = /(^|[\\/])(node_modules|\.git|dist|build|__pycache__|\.venv)[\\/]|(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock)$/i;
const PASS = /\.(png|jpe?g|gif|webp|bmp|pdf|ipynb|svg)$/i; // visual/structured: tool handles them

function decide(input) {
  const p = input.file_path || '';
  if (!p || PASS.test(p)) return null;
  if (JUNK.test(p)) return `Read blocked: ${p} is generated/vendored. Grep it or read a specific range if truly needed (offset/limit).`;
  if (input.offset != null || input.limit != null) return null;
  let st;
  try { st = fs.statSync(p); } catch { return null; }
  if (!st.isFile()) return null;
  if (st.size > MAX_BYTES) {
    const lines = fs.readFileSync(p, 'latin1').split('\n').length;
    if (lines > MAX_LINES) return `Read blocked: ${p} has ${lines} lines (${Math.round(st.size / 1024)} KB). Grep to locate, then Read with offset/limit. Pass allow_large only if the whole file is genuinely needed.`;
  }
  return null;
}

if (process.argv[2] === '--selftest') {
  const os = require('os'), path = require('path');
  const big = path.join(os.tmpdir(), 'rg-big.txt'), small = path.join(os.tmpdir(), 'rg-small.txt');
  fs.writeFileSync(big, 'x'.repeat(80).concat('\n').repeat(900));
  fs.writeFileSync(small, 'hi\n');
  const assert = require('assert');
  assert(decide({ file_path: big }));
  assert.equal(decide({ file_path: big, limit: 50 }), null);
  assert.equal(decide({ file_path: small }), null);
  assert(decide({ file_path: 'C:\\x\\node_modules\\a.js' }));
  assert.equal(decide({ file_path: 'C:\\x\\a.png' }), null);
  console.log('ok');
  process.exit(0);
}

let raw = '';
process.stdin.on('data', d => raw += d).on('end', () => {
  try {
    const j = JSON.parse(raw);
    if (j.tool_name !== 'Read') return;
    const why = decide(j.tool_input || {});
    if (why) console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: why } }));
  } catch { /* never block on hook error */ }
});
