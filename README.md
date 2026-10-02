# Agentic rules for C/C++ embedded development

Project-agnostic Claude Code skills and agents, meant to be reused as a template or a git submodule.

## Layout
```
.claude/
  skills/
    embedded-security-review/SKILL.md   security checklist + report format
    embedded-bug-review/SKILL.md        bugs / common-mistake checklist + report format
    embedded-obsolete-code-review/SKILL.md  deprecated / legacy / dead code checklist
    embedded-test-writing/SKILL.md      tests: host-first then HW/emulator, framework detection
    embedded-code-writing/SKILL.md      writing conventions: small units, thread-safe, minimal comments
  agents/
    embedded-code-reviewer.md           bugs + security + obsolete code (uses three skills)
    embedded-security-auditor.md        security only (uses embedded-security-review)
    embedded-test-writer.md             writes/runs tests (uses embedded-test-writing)
    embedded-code-writer.md             writes/modifies code (uses embedded-code-writing)
```

`AIAgentUsecaseHelper.md` is a tool-agnostic base input: give it to any AI to generate a project-specific `CLAUDE.md` (rules, role prompts, fill-in template).

The skills are the source of truth for the rules; section 2 of the helper is a condensed copy for tools without skill support. Edit the skill first, then the summary.

## Use in a project
Add this repo as a submodule (or clone it anywhere), then run the installer. It copies each skill and agent individually, so a project's own skills/agents are kept and existing names are skipped. Re-run it after updating the submodule to refresh the copies:
```
git submodule add <this-repo-url> .agentic
.agentic/scripts/install.sh .            # copies into ./.claude
.agentic/scripts/install.sh . --link     # symlinks instead (Claude Code may not load symlinked skills)
```
User-wide: `scripts/install.sh ~` installs into `~/.claude`.

Invoke: ask "use embedded-code-reviewer on src/" or "run embedded-security-auditor on the current diff".
