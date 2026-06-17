# messages/en.sh — CCTG English message catalog
#
# Each message is a CCTG_MSG_<KEY> scalar holding a printf template (Bash 3.2 compatible — no
# associative arrays). cc-tg.sh's t() looks up by key and emits `printf "$template" "$@"`.
# This file is the base catalog: cc-tg.sh always sources it first, then overlays the selected
# language. Keep the key set identical to ko.sh (key parity); only values differ per language.

CCTG_MSG_SHARED_CREATED="Created shared settings: %s (defaultMode=bypassPermissions + deny safety net)\n"
CCTG_MSG_ERR_NEED_JQ="ERROR: this action requires jq. Edit directly with 'cctg common edit', or install jq (brew install jq).\n"

CCTG_MSG_USAGE="Usage: %s <command> [args]\n  add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--channel <ch>] [--group <id>[:nomention][:allow=ids]]\n                         register a project bot (flags = non-interactive; telegram needs --id)\n                         --channel telegram|discord; --group seeds a discord server channel (repeatable)\n  rm  <name> [--purge]   unregister (--purge: also delete the state directory)\n  rename <old> <new> [--keep-dir]\n                         rename (default: also move the state directory.\n                         --keep-dir: keep the directory path, rename only)\n  config <name> [show|edit|mode <m|clear>|args <str>|snapshot <secs|off>]\n                         view/edit per-bot options (permission mode, extra args, log snapshot)\n  common [show|edit|mode <m>|deny add|rm <rule>|allow add|rm <rule>]\n                         view/edit shared permission policy (applies to all bots)\n  up   <name|all>        start\n  down <name|all>        stop\n  restart <name|all>     restart (down + up)\n  status [--json]        registration/run status (--json: machine-readable)\n  logs <name> [N]        last N log lines (default 50, without attaching)\n  attach <name>          attach tmux session (detach: Ctrl-b d)\n  lang [show|en|ko|clear]  view/change CLI output language\n  doctor                 diagnose dependencies, PATH, registry\n  update                 git pull then re-install\n  version                print version\n  help                   this help\n\nName rules: letters/digits/_/- only. Global channel names (telegram/discord/imessage/fakechat) are reserved.\n"

# Shared fragments
CCTG_MSG_FOLLOW_SHARED="follow shared"
CCTG_MSG_FOLLOW_SHARED_PAREN="(follow shared)"
CCTG_MSG_EMPTY_PAREN="(empty)"
CCTG_MSG_SHARED_WORD="shared"
CCTG_MSG_ISSUE_NO_CWD="no-cwd"
CCTG_MSG_ISSUE_NO_TOKEN="no-token"

# Common errors
CCTG_MSG_ERR_NOT_REGISTERED="ERROR: not a registered project: %s\n"
CCTG_MSG_ERR_BADNAME="ERROR: name may only contain letters/digits/_/-: '%s'\n"
CCTG_MSG_ERR_RESERVED="ERROR: '%s' is a reserved global channel name (%s). Its state dir would collide with that channel's global bot. Use another name.\n"
CCTG_MSG_ERR_FOREIGN_STATEDIR="ERROR: %s already holds another channel bot's state (.env/access.json, no cctg launch.env). Refusing to overwrite it. Use another name or move that directory aside.\n"
CCTG_MSG_ERR_ALREADY_REGISTERED="ERROR: already registered: %s\n"
CCTG_MSG_ERR_RUNNING_DOWN_FIRST="ERROR: it's running. Stop it first with '%s down %s'.\n"
CCTG_MSG_ERR_REGISTRY_UPDATE="ERROR: failed to update the registry\n"
CCTG_MSG_ERR_BAD_MODE="ERROR: invalid mode: '%s' (valid: %s)\n"

# up / down
CCTG_MSG_ERR_NO_CWD="ERROR: working directory not found: %s\n"
CCTG_MSG_ERR_NO_TOKEN="ERROR: token file not found: %s (run add first)\n"
CCTG_MSG_ALREADY_RUNNING="Already running: %s\n"
CCTG_MSG_UP_OK="UP   %s  (cwd=%s, state=%s, tmux=%s)\n"
CCTG_MSG_UP_SNAPSHOT_ON="  log snapshot: every %ss → state/last-session.log (survives crash/reboot)\n"
CCTG_MSG_DOWN_OK="DOWN %s\n"
CCTG_MSG_DOWN_STOPPED="Stopped: %s\n"

# add
CCTG_MSG_ADD_PROMPT_TOKEN="Bot token (issued by @BotFather, must be a NEW bot): "
CCTG_MSG_ERR_EMPTY_TOKEN="ERROR: token is empty\n"
CCTG_MSG_ADD_PROMPT_TGID="Your %s: "
CCTG_MSG_ERR_NOT_NUMERIC_ID="ERROR: not a numeric ID: '%s'\n"
CCTG_MSG_ADD_PROMPT_MODE="Permission mode [Enter=follow shared | %s]: "
CCTG_MSG_ERR_BAD_MODE_ADD="ERROR: invalid permission mode: '%s' (valid: %s)\n"
CCTG_MSG_ERR_ADD_UNKNOWN_FLAG="ERROR: unknown add flag: '%s' (valid: --id <num>, --token-env <VAR>, --token-stdin, --mode <m>, --channel <name>, --group <id>[:nomention][:allow=m1,m2])\n"
CCTG_MSG_ERR_ADD_FLAG_VALUE="ERROR: %s requires a value\n"
CCTG_MSG_ERR_ADD_BAD_ENVNAME="ERROR: '%s' is not a valid environment variable name\n"
CCTG_MSG_ERR_ADD_NEED_ID="ERROR: non-interactive add (--token-env/--token-stdin) requires --id <num>\n"
CCTG_MSG_ERR_ADD_BAD_GROUP_ID="ERROR: --group channel id must be numeric: '%s'\n"
CCTG_MSG_ERR_ADD_BAD_GROUP_MEMBER="ERROR: --group allow member must be numeric: '%s'\n"
CCTG_MSG_ERR_CHANNEL_UNSUPPORTED="ERROR: channel '%s' is not supported yet (implemented: %s)\n"
CCTG_MSG_ADD_DONE="Registered: %s → cwd=%s, state=%s\n"
CCTG_MSG_ADD_DONE_ALLOWLIST="  seeded %s into the allowlist (no pairing needed)\n"
CCTG_MSG_ADD_DONE_PAIRING="  DM the bot to get a pairing code, then approve it from the bot's /access skill.\n"
CCTG_MSG_ADD_DONE_MODE="  permission mode: %s  (shared: %s common / per-bot: %s config %s)\n"
CCTG_MSG_ADD_DONE_NEXT="Next: %s up %s  → DM the bot and it responds right away.\n"

# rm
CCTG_MSG_RM_DONE="Unregistered: %s\n"
CCTG_MSG_RM_PURGE_REFUSE_GLOBAL="  refused: will not delete the global bot directory: %s\n"
CCTG_MSG_RM_PURGE_DELETED="  deleted state directory: %s\n"
CCTG_MSG_RM_PURGE_OUTSIDE="  note: state directory is outside CHANNELS_DIR; not auto-deleting: %s\n"
CCTG_MSG_RM_KEEP="  kept state directory: %s (incl. token/allowlist). Use --purge to delete fully.\n"

# rename
CCTG_MSG_ERR_SAME_NAME="ERROR: old and new names are identical: %s\n"
CCTG_MSG_ERR_TARGET_EXISTS="ERROR: target state directory already exists: %s (move cancelled)\n"
CCTG_MSG_ERR_MOVE_FAILED="ERROR: failed to move state directory: %s → %s\n"
CCTG_MSG_RENAME_MOVED="  moved state directory: %s → %s\n"
CCTG_MSG_RENAME_KEPT="  kept state directory: %s\n"
CCTG_MSG_RENAME_DONE="Renamed: %s → %s\n"
CCTG_MSG_RENAME_NEXT="Next: %s up %s\n"

# config
CCTG_MSG_CFG_SHOW_HEADER="# %s bot options (%s)\n"
CCTG_MSG_CFG_SHOW_CHANNEL="  channel: %s\n"
CCTG_MSG_CFG_SHOW_MODE="  permission mode: %s\n"
CCTG_MSG_CFG_SHOW_SNAPSHOT="  log snapshot: %s\n"
CCTG_MSG_CFG_SHOW_LAUNCHENV="--- launch.env ---\n"
CCTG_MSG_ERR_CONFIG_MODE_USAGE="Usage: %s config %s mode <mode|clear>  (modes: %s)\n"
CCTG_MSG_CFG_MODE_CLEARED="%s permission mode: (follow shared)\n"
CCTG_MSG_CFG_MODE_SET="%s permission mode: %s\n"
CCTG_MSG_APPLY_RESTART="  to apply: %s restart %s\n"
CCTG_MSG_CFG_ARGS_SET="%s CLAUDE_EXTRA_ARGS: %s\n"
CCTG_MSG_CFG_SNAPSHOT_SET="%s log snapshot: every %ss\n"
CCTG_MSG_CFG_SNAPSHOT_OFF="%s log snapshot: off\n"
CCTG_MSG_ERR_CONFIG_SNAPSHOT_USAGE="Usage: %s config %s snapshot <seconds|off>  (min 5; off to disable)\n"
CCTG_MSG_ERR_BAD_SNAPSHOT="ERROR: snapshot interval must be an integer >= 5 seconds (or 'off'): '%s'\n"
CCTG_MSG_ERR_CONFIG_UNKNOWN="ERROR: unknown config action: %s\n"
CCTG_MSG_CFG_USAGE="Usage: %s config <name> [show | edit | mode <mode|clear> | args <string> | snapshot <seconds|off>]\n"

# common
CCTG_MSG_COMMON_SHOW_HEADER="# Shared settings (%s)\n"
CCTG_MSG_ERR_COMMON_MODE_USAGE="Usage: %s common mode <mode>  (modes: %s)\n"
CCTG_MSG_COMMON_MODE_SET="Shared defaultMode: %s  (applies after restarting all bots)\n"
CCTG_MSG_COMMON_RULE_ADD="%s += %s  (applies after restarting all bots)\n"
CCTG_MSG_COMMON_RULE_RM="%s -= %s  (applies after restarting all bots)\n"
CCTG_MSG_ERR_COMMON_OP="ERROR: %s supports only add|rm\n"
CCTG_MSG_ERR_COMMON_UNKNOWN="ERROR: unknown common action: %s\n"
CCTG_MSG_COMMON_USAGE="Usage: %s common [show | edit | mode <mode> | deny add|rm <rule> | allow add|rm <rule>]\n"

# status
CCTG_MSG_STATUS_GLOBAL="Global bots: %s (not managed by this script)\n"
CCTG_MSG_STATUS_PROJECT_HEADER="--- project bots ---\n"
CCTG_MSG_STATUS_RUNNING="  [RUNNING] %s%s  (tmux=%s)\n"
CCTG_MSG_STATUS_BROKEN="  [BROKEN ] %s  (%s)\n"
CCTG_MSG_STATUS_CHANNEL="            channel=%s\n"
CCTG_MSG_STATUS_CHANNEL_TOPO="            channel=%s (%s, %s groups)\n"
CCTG_MSG_STATUS_HINT_NO_CWD="            ↳ working dir missing: %s — create it, or '%s rm %s' and re-add with the right path\n"
CCTG_MSG_STATUS_HINT_NO_TOKEN="            ↳ token missing: %s/.env — '%s rm %s' then re-add, or put %s= in that file\n"
CCTG_MSG_STATUS_STOPPED="  [stopped] %s\n"
CCTG_MSG_ERR_STATUS_UNKNOWN_FLAG="ERROR: unknown status flag: '%s' (valid: --json)\n"
CCTG_MSG_STATUS_PATHS="            cwd=%s  state=%s\n"
CCTG_MSG_STATUS_MODE="            mode=%s\n"
CCTG_MSG_STATUS_UPTIME="  up %s"
CCTG_MSG_STATUS_NONE="  (no project bots registered)\n"

# logs / attach
CCTG_MSG_LOGS_STOPPED="Stopped: %s (no logs). Run '%s up %s' then try again.\n"
CCTG_MSG_LOGS_SNAPSHOT="# %s is stopped — showing the last saved session log (from the most recent 'down' or periodic snapshot).\n"
CCTG_MSG_ERR_NOT_RUNNING="ERROR: not running: %s (run '%s up %s' first)\n"
CCTG_MSG_ATTACH_DETACH_HINT="(to detach, press Ctrl-b then d)\n"

# update
CCTG_MSG_ERR_REPO_NOT_FOUND="ERROR: cannot find the cctg repo location.\n"
CCTG_MSG_ERR_REPO_HINT="  Run install.sh once in the repo to create the manifest (%s).\n"
CCTG_MSG_UPDATE_START="Updating: %s  (mode=%s, current v%s)\n"
CCTG_MSG_ERR_GIT_PULL="ERROR: git pull failed (local changes or fast-forward not possible). Check the repo directly.\n"
CCTG_MSG_UPDATE_VERSION="Version: v%s → v%s\n"
CCTG_MSG_UPDATE_COMPLETION_HINT="Open a new terminal to pick up completions (zsh, apply now: rm -f ~/.zcompdump*; exec zsh).\n"

# doctor
CCTG_MSG_DOCTOR_HEADER="cctg doctor (v%s)\n"
CCTG_MSG_DOCTOR_DEPS="--- dependencies ---\n"
CCTG_MSG_DOCTOR_OK="  ok   %s (%s)\n"
CCTG_MSG_DOCTOR_WARN_CAFFEINATE="  warn %s missing (not macOS → cannot prevent sleep)\n"
CCTG_MSG_DOCTOR_MISS="  MISS %s (required)\n"
CCTG_MSG_DOCTOR_WARN_JQ="  warn jq missing (optional — needed for 'common mode/deny/allow'. 'common edit' still works)\n"
CCTG_MSG_DOCTOR_PATH="--- PATH ---\n"
CCTG_MSG_DOCTOR_PATH_OK="  ok   ~/.local/bin is on PATH\n"
CCTG_MSG_DOCTOR_PATH_WARN="  warn ~/.local/bin is not on PATH\n"
CCTG_MSG_DOCTOR_REGISTRY="--- registry ---\n"
CCTG_MSG_DOCTOR_FILE="  file: %s\n"
CCTG_MSG_DOCTOR_REGISTRY_COUNT="  registered project bots: %s\n"
CCTG_MSG_DOCTOR_SHARED="--- shared settings (permission policy) ---\n"
CCTG_MSG_DOCTOR_DEFAULTMODE="  defaultMode: %s\n"
CCTG_MSG_DOCTOR_DENYALLOW="  deny: %s / allow: %s\n"
CCTG_MSG_DOCTOR_NOJQ="  (no jq — check with 'cctg common show')\n"
CCTG_MSG_DOCTOR_SHARED_NONE="  (none yet — created on first add/up)\n"
CCTG_MSG_DOCTOR_PLUGIN_HINT="  (the channel plugins must be installed globally, e.g. /plugin install <channel>@claude-plugins-official for: %s)\n"

# version / dispatcher
CCTG_MSG_VERSION_LINE="%s %s\n"
CCTG_MSG_ERR_UNKNOWN_CMD="ERROR: unknown command: %s\n"

# lang
CCTG_MSG_LANG_CURRENT="Current language: %s (source: %s)\n"
CCTG_MSG_LANG_SET="Language set: %s\n"
CCTG_MSG_LANG_CLEARED="Language preference cleared (reverting to auto-detect)\n"
CCTG_MSG_ERR_LANG_INVALID="ERROR: unsupported language: '%s' (supported: en, ko)\n"
CCTG_MSG_LANG_USAGE="Usage: %s lang [show | en | ko | clear]\n"
