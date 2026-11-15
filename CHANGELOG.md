# Changelog

Every release of this repo, newest first, in the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as `README.md` defines it for this repo: a major release asks a project to act, and its entries say how.

## [1.0.0] - 2026-11-15

The `matias-pizarro/skills` repo becomes `matias-pizarro/agentic_workflow`, and takes in the playbook, which until now was its own repo, with its history.

### Added

- The playbook: `docs/index.md` (what the process is and why each rule exists), `docs/kickoff.md` (the first hour), `docs/rules.md` (the rules, for agents).
- `tools/team.sh`, the team script, and `tools/src-pre-commit`, the lead's commit guard.
- `.githooks/pre-commit`, for clones of this repo: refuses a commit that empties a file by accident; turn it on with `git config core.hooksPath .githooks`.
- `README.md`: the layout, how a project uses the repo, what each version number means, and how to cut a release.

### Changed

- The repo's name: install skills with `npx skills@latest add matias-pizarro/agentic_workflow ...`. GitHub redirects the old name; reinstall a skill from the new name to update its lock file entry.
- The playbook's paths. A project that cloned the playbook as `<root>/playbook` must:
  - clone this repo at `v1.0.0` as `<root>/agentic_workflow` (`docs/kickoff.md` step 4);
  - point the rules line in its `AGENTS.md`, and every task file, at `<root>/agentic_workflow/docs/rules.md` (was `<root>/playbook/RULES.md`);
  - repoint the team script and the commit guard, wherever they are linked or copied from, to `<root>/agentic_workflow/tools/` (was `<root>/playbook/tools/`), and run `team.sh selftest` through the new path.

### Fixed

- `skills/review-loop/SKILL.md`, emptied by a commit on main (8639493), is restored.

[1.0.0]: https://github.com/matias-pizarro/agentic_workflow/releases/tag/v1.0.0
