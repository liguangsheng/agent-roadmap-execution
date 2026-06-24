#!/usr/bin/env bash
# install.sh - Install the roadmap-driven skill.
#
# Installs SKILL.md, agents/openai.yaml, and scripts/roadmap_lint.py into the
# skills directory of one or more AI coding agents so the skill can be invoked
# as roadmap-driven. The same SKILL.md works for every supported tool;
# only the install directory and invocation differ.
#
# Supported agents and default targets:
#   codex     ~/.codex/skills/roadmap-driven            (override: CODEX_SKILLS_DIR)
#   claude    ~/.claude/skills/roadmap-driven           (override: CLAUDE_SKILLS_DIR)
#   opencode  ~/.config/opencode/skills/roadmap-driven  (override: OPENCODE_SKILLS_DIR)
#
# By default the script installs from the directory it lives in. If it is run
# without neighbouring skill files (e.g. curl ... | bash), it clones the public
# repository instead. Use --git to force a remote clone, --link for a symlink
# install, and --target to choose an explicit destination.
#
# Usage:
#   ./install.sh [options]
#
# Options:
#   --agent NAME   Install for codex, claude, opencode, or all. May be repeated.
#                  Default: auto-detect installed tools (fallback: codex).
#   --target DIR   Install into DIR explicitly, ignoring per-agent defaults.
#   --git URL      Clone and install from URL instead of this script's directory.
#   --link         Symlink each target to the source (developer mode) so updates
#                  to the source take effect immediately. Copies by default.
#   --force        Overwrite a target even when it holds unrelated files.
#   --no-verify    Skip the post-install verification.
#   --python BIN   Python interpreter for the lint smoke test (default: auto).
#   -h, --help     Show this help and exit.

set -euo pipefail

readonly DEFAULT_GIT_URL="https://github.com/liguangsheng/roadmap-driven.git"
readonly SKILL_NAME="roadmap-driven"
readonly SUPPORTED_AGENTS="codex claude opencode"

# --- output helpers ----------------------------------------------------------

if [ -t 1 ]; then
  C_BOLD=$'\033[1m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_RESET=$'\033[0m'
else
  C_BOLD=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_RESET=''
fi

log()  { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$C_BOLD" "$C_RESET" "$*" >&2; }
warn() { printf '%swarning:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

print_help() {
  sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- arg parsing -------------------------------------------------------------

need_arg() { [ "$2" -ge 2 ] || die "$1 requires a value"; }

parse_args() {
  FORCE=no
  LINK=no
  VERIFY=yes
  PYTHON=""
  GIT_URL=""
  TARGET=""
  AGENTS_SELECTED=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --agent)
        need_arg "$1" "$#"
        case "$2" in
          codex|claude|opencode|all) AGENTS_SELECTED="$AGENTS_SELECTED $2";;
          *) die "unknown agent: $2 (expected codex, claude, opencode, or all)";;
        esac
        shift 2;;
      --target)    need_arg "$1" "$#"; TARGET="$2"; shift 2;;
      --git)       need_arg "$1" "$#"; GIT_URL="$2"; shift 2;;
      --python)    need_arg "$1" "$#"; PYTHON="$2"; shift 2;;
      --link)      LINK=yes; shift;;
      --force)     FORCE=yes; shift;;
      --no-verify) VERIFY=no; shift;;
      -h|--help)   print_help; exit 0;;
      *)           die "unknown option: $1 (try --help)";;
    esac
  done
}

# --- agent resolution --------------------------------------------------------

normalize_agents() {
  # Echo the requested agents as a deduped list in canonical order.
  # Expands "all" and ignores unknown tokens (already validated at parse time).
  local raw="$1" out=""
  case " $raw " in *" all "*) raw="$SUPPORTED_AGENTS";; esac
  local a
  for a in $SUPPORTED_AGENTS; do
    case " $raw " in *" $a "*) out="$out $a";; esac
  done
  printf '%s' "${out# }"
}

agent_default_dir() {
  case "$1" in
    codex)    printf '%s' "${CODEX_SKILLS_DIR:-$HOME/.codex/skills}/$SKILL_NAME";;
    claude)   printf '%s' "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/$SKILL_NAME";;
    opencode) printf '%s' "${OPENCODE_SKILLS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills}/$SKILL_NAME";;
    *)        die "unknown agent: $1";;
  esac
}

agent_present() {
  case "$1" in
    codex)    [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1;;
    claude)   [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1;;
    opencode) [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/opencode" ] || command -v opencode >/dev/null 2>&1;;
    *)        return 1;;
  esac
}

resolve_agents() {
  # Sets AGENTS to a space-separated list of agents to install for.
  AGENTS="$(normalize_agents "$AGENTS_SELECTED")"
  [ -n "$AGENTS" ] && return 0

  local a
  for a in $SUPPORTED_AGENTS; do
    if agent_present "$a"; then AGENTS="$AGENTS $a"; fi
  done
  AGENTS="${AGENTS# }"

  if [ -n "$AGENTS" ]; then
    info "Detected agent tools: $AGENTS"
  else
    AGENTS="codex"
    warn "No codex/claude/opencode config detected; defaulting to codex. Use --agent codex|claude|opencode|all to choose."
  fi
}

invoke_hint() {
  case "$1" in
    codex)    log "  invoke in Codex:     \$$SKILL_NAME";;
    claude)   log "  use in Claude Code:  ask Claude to use the $SKILL_NAME skill (auto-discovered by description)";;
    opencode) log "  use in opencode:     ask opencode to use the $SKILL_NAME skill (auto-discovered by description)";;
    *)        log "  Codex:                  \$$SKILL_NAME"
              log "  Claude Code / opencode: auto-discovered; ask the agent to use $SKILL_NAME";;
  esac
}

# --- source resolution -------------------------------------------------------

resolve_source() {
  if [ -n "$GIT_URL" ]; then
    clone_source
    return
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "$script_dir/SKILL.md" ] && [ -f "$script_dir/scripts/roadmap_lint.py" ]; then
    SOURCE="$script_dir"
  else
    info "No local skill files found next to install.sh; cloning $DEFAULT_GIT_URL"
    GIT_URL="$DEFAULT_GIT_URL"
    clone_source
  fi
}

clone_source() {
  command -v git >/dev/null 2>&1 || die "git is required to clone $GIT_URL but was not found."
  command -v mktemp >/dev/null 2>&1 || die "mktemp is required but was not found."
  TMP="$(mktemp -d)"
  info "Cloning $GIT_URL ..."
  if ! git clone --depth 1 "$GIT_URL" "$TMP/repo" >&2; then
    die "failed to clone $GIT_URL"
  fi
  [ -f "$TMP/repo/SKILL.md" ] || die "cloned repository has no SKILL.md: $GIT_URL"
  SOURCE="$TMP/repo"
}

# --- target handling ---------------------------------------------------------

target_state() {
  # Prints: absent | reinstall | occupied
  if [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then printf 'absent'; return 0; fi
  if [ -L "$TARGET" ]; then printf 'reinstall'; return 0; fi
  if [ -f "$TARGET" ]; then printf 'occupied'; return 0; fi
  if [ -d "$TARGET" ]; then
    if [ -z "$(ls -A "$TARGET" 2>/dev/null)" ]; then printf 'reinstall'; return 0; fi
    if [ -f "$TARGET/SKILL.md" ]; then printf 'reinstall'; return 0; fi
    printf 'occupied'; return 0
  fi
  printf 'occupied'; return 0
}

prepare_target() {
  local state
  state="$(target_state)"
  case "$state" in
    absent) ;;
    reinstall)
      rm -rf "$TARGET"
      info "Removing previous install at $TARGET"
      ;;
    occupied)
      if [ "$FORCE" = yes ]; then
        rm -rf "$TARGET"
        info "Overwriting occupied target at $TARGET (--force)"
      else
        die "target exists and does not look like this skill: $TARGET (pass --force to overwrite, or --target to choose another location)"
      fi
      ;;
  esac
}

# --- install + verify --------------------------------------------------------

do_install() {
  mkdir -p "$(dirname "$TARGET")"
  if [ "$LINK" = yes ]; then
    mkdir -p "$TARGET" 2>/dev/null || true
    rm -rf "$TARGET"
    ln -sfn "$SOURCE" "$TARGET"
    info "Linked $TARGET -> $SOURCE"
  else
    mkdir -p "$TARGET"
    cp -R "$SOURCE/." "$TARGET/"
    rm -rf "$TARGET/.git"
    if [ -f "$TARGET/scripts/roadmap_lint.py" ]; then
      chmod +x "$TARGET/scripts/roadmap_lint.py" 2>/dev/null || true
    fi
    info "Installed files into $TARGET"
  fi
}

detect_python() {
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done
}

verify() {
  [ "$VERIFY" = yes ] || return 0

  if [ ! -f "$TARGET/SKILL.md" ]; then
    die "verification failed: $TARGET/SKILL.md is missing"
  fi

  if [ ! -f "$TARGET/scripts/roadmap_lint.py" ]; then
    warn "scripts/roadmap_lint.py is missing; roadmap lint will be unavailable."
    return 0
  fi

  local py="${PYTHON:-$(detect_python)}"
  if [ -z "$py" ]; then
    warn "No python interpreter found; skipped roadmap_lint smoke test."
    return 0
  fi

  if ( cd "$HOME" && "$py" "$TARGET/scripts/roadmap_lint.py" --allow-missing ) >/dev/null 2>&1; then
    info "roadmap_lint.py smoke test passed ($py)."
  else
    warn "roadmap_lint.py smoke test failed with $py; the script is installed but may not run in this environment."
  fi
}

print_done() {
  log "${C_GREEN}installed${C_RESET} $SKILL_NAME (${AGENT}) -> $TARGET"
  invoke_hint "$AGENT"
  if [ -f "$TARGET/scripts/roadmap_lint.py" ]; then
    log "  lint a roadmap:      python \"$TARGET/scripts/roadmap_lint.py\" ."
  fi
}

install_one() {
  TARGET="$1"
  AGENT="$2"
  prepare_target
  do_install
  verify
  print_done
}

# --- main --------------------------------------------------------------------

cleanup() { if [ -n "${TMP:-}" ]; then rm -rf "$TMP"; fi; }
trap cleanup EXIT

main() {
  parse_args "$@"
  : "${HOME:?HOME is not set; cannot determine a default install location. Set a *_SKILLS_DIR override or pass --target.}"

  resolve_source

  if [ -n "$TARGET" ]; then
    # Explicit destination: install once; use a single selected agent for the
    # invocation hint, otherwise print hints for all tools.
    local hint_agent
    hint_agent="$(normalize_agents "$AGENTS_SELECTED")"
    case "$hint_agent" in
      "" | *" "*) install_one "$TARGET" "custom";;
      *)          install_one "$TARGET" "$hint_agent";;
    esac
    return
  fi

  resolve_agents
  local a
  for a in $AGENTS; do
    install_one "$(agent_default_dir "$a")" "$a"
  done
}

main "$@"
