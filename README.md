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
    embedded-userdefined-{code-writer,code-reviewer,security-auditor,test-writer}/SKILL.md  empty by default; your own rules, one per agent
  agents/
    embedded-code-reviewer.md           bugs + concurrency + security + obsolete code + best practices (uses the three review skills + its user-defined skill)
    embedded-security-auditor.md        security only (uses embedded-security-review + user-defined skill)
    embedded-test-writer.md             writes/runs tests (uses embedded-test-writing + user-defined skill)
    embedded-code-writer.md             writes/modifies code (uses embedded-code-writing + user-defined skill)
```

`AIAgentUsecaseHelper.md` is a tool-agnostic base input: give it to any AI to generate a project-specific `CLAUDE.md` (rules, role prompts, fill-in template).

The skills are the source of truth for the rules; section 2 of the helper is a condensed copy for tools without skill support. Edit the skill first, then the summary.

## User-defined skills
Each agent also loads an `embedded-userdefined-<role>` skill (`code-writer`, `code-reviewer`, `security-auditor`, `test-writer`). They ship empty: put project-specific rules there. The installer never overwrites them once they exist, so your rules survive updates.

## Use in a project
Add this repo as a submodule (or clone it anywhere), then run the installer. It copies each skill and agent individually, so a project's other skills/agents are kept. Existing copies of these skills and agents are replaced, except `embedded-userdefined-*` skills, which are never overwritten once present. Re-run it after updating the submodule to refresh the copies:
```
git submodule add <this-repo-url> .agentic
.agentic/scripts/install.sh .            # copies into ./.claude
```
User-wide: `scripts/install.sh ~` installs into `~/.claude`.

## Agent configuration
Each agent sets `model`, `effort` and `maxTurns` in its frontmatter (see the table in `AIAgentUsecaseHelper.md`). Stronger models/effort for review and security, cheaper for writing. `maxTurns` is the only per-agent limit (no token cap exists). The installer overwrites agent files, so change values in this repo or re-apply them after installing.

Invoke: ask "use embedded-code-reviewer on src/" or "run embedded-security-auditor on the current diff".
