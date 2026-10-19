# Working rules

Ponytail (what to build) and caveman (how to write) load via
`~/.claude/hooks/mode-hook.js`. This file only covers what neither does.

## Context discipline
- Grep/Glob to locate, then Read only the needed range (`offset`/`limit`). Never
  read a whole file to see one function.
- Cap tool output: `head`, `-m`, `head_limit`. Never paste a log dump; quote the
  one decisive line.
- No subagents, workflows, or parallel fan-out unless asked or the search is
  genuinely broad. One agent that reports a conclusion beats five that report files.
- Don't re-read a file just edited. Don't re-derive settled facts.
- `/clear` between unrelated tasks - a 1M window delays auto-compact, so a stale
  session re-sends a huge prefix every turn.
- Screenshots/images stay in context and get re-read on every later call. Verify
  state by query (scripts, property reads, logs) first; take a screenshot only
  for a genuinely visual check, one at a time, never as a routine after each edit.

## Memory vault
Memories live in `%USERPROFILE%\Vault`, which is also an Obsidian vault (point
this at your own). The `obsidian` CLI works on it when Obsidian is running
(`Obsidian.com` on PATH; enable via Settings > General > Advanced).

Use the CLI for **navigation and structured writes**, not for reading content:
- `obsidian search query="..." limit=10` - indexed, capped. Good.
- `obsidian backlinks file="..."` - resolves aliases and heading links; grep can't.
- `obsidian tags sort=count counts` - whole-vault shape in a few lines.
- `obsidian property:set name=... value=... file=...` - edits one frontmatter field
  without rewriting the note.
- **Not** `obsidian read file="..."` - returns the entire note. Use a ranged Read.

If Obsidian is not running the CLI fails; fall back to Grep/Read, don't retry.

**YAML frontmatter: never put a Windows path in a double-quoted scalar.** `"...\Docs..."`
is an invalid escape, and Obsidian silently fails to parse the WHOLE block - tags and
aliases vanish while grep still sees the text. Use a single-quoted scalar or no quotes.
Verify with `obsidian aliases file="<note>"`; "No aliases found." on a note that has
them means the frontmatter is broken.

## Memory hygiene
A memory is one fact plus pointers, never a log. If a note starts accumulating
dated sections, the log belongs in a knowledge base and the memory keeps the
pointer plus only the facts that change what you do next. The vault's git
pre-commit hook warns at 8 KB or 3+ dated headings - heed it, don't silence it.
The vault is a git repo: commit after any session that changed it.

## Platform
Windows 11. PowerShell 7 primary, Git Bash available - each takes its own syntax.
Scratch files go to the session scratchpad, never `/tmp`, never the project.
