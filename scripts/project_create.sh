#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# project_create.sh — SylixOS project creation
#
# Two usage modes:
#   Interactive:  bash project_create.sh
#   CLI (Claude): bash project_create.sh --name=myapp --type=cmake --template=app ...
# ============================================================================

# --- Color helpers ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header(){ echo -e "\n${BOLD}=== $* ===${NC}"; }

# --- Valid values ---
VALID_TYPES="cmake automake realevo python cython go javascript ros2"
VALID_TEMPLATES="app lib ko common shared_lib"

# --- Collected parameters (global) ---
NAME=""
TYPE=""
TEMPLATE=""
SOURCE=""
BRANCH=""
DEBUG_LEVEL=""
MAKE_TOOL=""
QUIET=false

# --- Flags ---
CLI_MODE=false
DRY_RUN=false
AUTO_CONFIRM=false

# ============================================================================
# CLI argument parsing
# ============================================================================

parse_args() {
  if [[ $# -eq 0 ]]; then
    CLI_MODE=false
    return 0
  fi

  for arg in "$@"; do
    case "$arg" in
      --help|-h)
        show_help
        exit 0
        ;;
      --dry-run)
        DRY_RUN=true
        CLI_MODE=true
        ;;
      --yes|--confirm)
        AUTO_CONFIRM=true
        CLI_MODE=true
        ;;
      --name=*)
        NAME="${arg#*=}"
        CLI_MODE=true
        ;;
      --type=*)
        TYPE="${arg#*=}"
        CLI_MODE=true
        ;;
      --template=*)
        TEMPLATE="${arg#*=}"
        CLI_MODE=true
        ;;
      --source=*)
        SOURCE="${arg#*=}"
        CLI_MODE=true
        ;;
      --branch=*)
        BRANCH="${arg#*=}"
        CLI_MODE=true
        ;;
      --debug-level=*)
        DEBUG_LEVEL="${arg#*=}"
        CLI_MODE=true
        ;;
      --make-tool=*)
        MAKE_TOOL="${arg#*=}"
        CLI_MODE=true
        ;;
      --quiet)
        QUIET=true
        CLI_MODE=true
        ;;
      *)
        error "未知参数: $arg"
        echo "使用 --help 查看帮助" >&2
        exit 1
        ;;
    esac
  done
}

# Infer project name from git URL if --name not provided
infer_name_from_source() {
  if [[ -n "$NAME" ]]; then
    return 0
  fi

  if [[ -n "$SOURCE" ]]; then
    # Extract last path segment, strip .git suffix
    local basename
    basename="${SOURCE##*/}"
    basename="${basename%.git}"
    if [[ -n "$basename" ]]; then
      NAME="$basename"
      info "从源地址推断工程名称: ${GREEN}${NAME}${NC}"
    fi
  fi
}

# ============================================================================
# Validation
# ============================================================================

check_required() {
  local missing=()

  [[ -z "$NAME" ]] && missing+=("--name (无法从 --source 推断)")
  [[ -z "$TYPE" ]] && missing+=("--type")

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "缺少必填参数: ${missing[*]}"
    return 1
  fi
  return 0
}

validate_params() {
  local errors=()

  # Validate type
  if [[ -n "$TYPE" && ! " $VALID_TYPES " =~ " $TYPE " ]]; then
    errors+=("无效的工程类型: '$TYPE'。可选值: $VALID_TYPES")
  fi

  # Validate template
  if [[ -n "$TEMPLATE" && ! " $VALID_TEMPLATES " =~ " $TEMPLATE " ]]; then
    errors+=("无效的模板类型: '$TEMPLATE'。可选值: $VALID_TEMPLATES")
  fi

  # Validate debug-level
  if [[ -n "$DEBUG_LEVEL" && "$DEBUG_LEVEL" != "debug" && "$DEBUG_LEVEL" != "release" ]]; then
    errors+=("无效的 debug-level: '$DEBUG_LEVEL'。可选值: debug, release")
  fi

  # Validate make-tool
  if [[ -n "$MAKE_TOOL" && "$MAKE_TOOL" != "make" && "$MAKE_TOOL" != "ninja" ]]; then
    errors+=("无效的 make-tool: '$MAKE_TOOL'。可选值: make, ninja")
  fi

  # Validate branch requires source
  if [[ -n "$BRANCH" && -z "$SOURCE" ]]; then
    errors+=("指定了 --branch 但未指定 --source")
  fi

  # Report errors
  if [[ ${#errors[@]} -gt 0 ]]; then
    error "参数校验失败："
    for e in "${errors[@]}"; do
      echo -e "  ${RED}• $e${NC}"
    done
    return 1
  fi
  return 0
}

# ============================================================================
# Interactive utility functions
# ============================================================================

select_from_list() {
  local prompt="$1"
  shift
  local options=("$@")
  local count=${#options[@]}

  echo -e "\n${BOLD}${prompt}${NC}"
  for i in "${!options[@]}"; do
    printf "  %2d) %s\n" $((i + 1)) "${options[$i]}"
  done

  while true; do
    read -rp "请输入编号 [1-${count}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      REPLY=$((choice - 1))
      return 0
    fi
    error "无效输入，请输入 1 到 ${count} 之间的数字"
  done
}

input_text() {
  local prompt="$1"
  local required="${2:-true}"

  echo -e "\n${BOLD}${prompt}${NC}"
  if [[ "$required" == "false" ]]; then
    echo -e "  (可选，直接回车跳过)"
  fi

  while true; do
    read -rp "> " text
    if [[ -z "$text" && "$required" == "false" ]]; then
      echo ""
      return 0
    fi
    if [[ -z "$text" ]]; then
      error "输入不能为空"
      continue
    fi
    echo "$text"
    return 0
  done
}

# ============================================================================
# Interactive mode-specific parameter collection
# ============================================================================

collect_interactive_params() {
  # Name
  NAME=$(input_text "请输入工程名称 (name)：")
  info "工程名称: ${GREEN}${NAME}${NC}"

  # Type
  header "选择构建类型"
  local types=(cmake automake realevo python cython go javascript ros2)
  local type_labels=(
    "cmake       — CMake 构建系统"
    "automake    — Automake 构建系统"
    "realevo     — RealEvo-IDE 兼容"
    "python      — Python 工程"
    "cython      — Cython 工程"
    "go          — Go 工程"
    "javascript  — JavaScript 工程"
    "ros2        — ROS2 工程"
  )
  select_from_list "请选择构建类型：" "${type_labels[@]}"
  TYPE="${types[$REPLY]}"
  info "构建类型: ${GREEN}${TYPE}${NC}"

  # Template
  header "选择工程模板"
  local templates=(app lib ko common shared_lib)
  local template_labels=(
    "app        — 应用程序"
    "lib        — 动态库"
    "ko         — 内核模块"
    "common     — 通用模板"
    "shared_lib — RealEvo-IDE 兼容动态库"
  )
  template_labels+=("(不指定模板)")
  select_from_list "请选择模板：" "${template_labels[@]}"
  if [[ $REPLY -lt ${#templates[@]} ]]; then
    TEMPLATE="${templates[$REPLY]}"
    info "工程模板: ${GREEN}${TEMPLATE}${NC}"
  else
    info "不指定模板"
  fi

  # Source
  SOURCE=$(input_text "请输入源码路径或 Git 仓库地址 (source)：" "false")
  if [[ -n "$SOURCE" ]]; then
    info "源码: ${GREEN}${SOURCE}${NC}"
  fi

  # Branch (only if source looks like a git URL)
  if [[ -n "$SOURCE" && "$SOURCE" =~ (git@|\.git$|ssh://|https://) ]]; then
    BRANCH=$(input_text "请输入 Git 分支名称 (branch)：" "false")
    if [[ -n "$BRANCH" ]]; then
      info "分支: ${GREEN}${BRANCH}${NC}"
    fi
  fi

  # Debug level
  header "选择构建级别"
  select_from_list "请选择 debug-level：" "debug" "release" "(使用默认值)"
  case $REPLY in
    0) DEBUG_LEVEL="debug" ;;
    1) DEBUG_LEVEL="release" ;;
    2) DEBUG_LEVEL="" ;;
  esac
  if [[ -n "$DEBUG_LEVEL" ]]; then
    info "构建级别: ${GREEN}${DEBUG_LEVEL}${NC}"
  fi

  # Make tool
  header "选择构建工具"
  select_from_list "请选择 make-tool：" "make" "ninja" "(使用默认值)"
  case $REPLY in
    0) MAKE_TOOL="make" ;;
    1) MAKE_TOOL="ninja" ;;
    2) MAKE_TOOL="" ;;
  esac
  if [[ -n "$MAKE_TOOL" ]]; then
    info "构建工具: ${GREEN}${MAKE_TOOL}${NC}"
  fi
}

# ============================================================================
# Command building
# ============================================================================

build_command() {
  local cmd="rl-project create"

  cmd+=" --name=${NAME}"
  cmd+=" --type=${TYPE}"

  [[ -n "$TEMPLATE" ]]    && cmd+=" --template=${TEMPLATE}"
  [[ -n "$SOURCE" ]]      && cmd+=" --source=${SOURCE}"
  [[ -n "$BRANCH" ]]      && cmd+=" --branch=${BRANCH}"
  [[ -n "$DEBUG_LEVEL" ]] && cmd+=" --debug-level=${DEBUG_LEVEL}"
  [[ -n "$MAKE_TOOL" ]]   && cmd+=" --make-tool=${MAKE_TOOL}"
  [[ "$QUIET" == true ]]  && cmd+=" --quiet"

  echo "$cmd"
}

# ============================================================================
# Summary & execution
# ============================================================================

show_summary() {
  local cmd="$1"

  header "命令预览 (Dry Run)"
  echo ""
  echo -e "  工程名称:  ${GREEN}${NAME}${NC}"
  echo -e "  构建类型:  ${GREEN}${TYPE}${NC}"
  [[ -n "$TEMPLATE" ]]    && echo -e "  工程模板:  ${GREEN}${TEMPLATE}${NC}"
  [[ -n "$SOURCE" ]]      && echo -e "  源码来源:  ${GREEN}${SOURCE}${NC}"
  [[ -n "$BRANCH" ]]      && echo -e "  Git 分支:  ${GREEN}${BRANCH}${NC}"
  [[ -n "$DEBUG_LEVEL" ]] && echo -e "  构建级别:  ${GREEN}${DEBUG_LEVEL}${NC}"
  [[ -n "$MAKE_TOOL" ]]   && echo -e "  构建工具:  ${GREEN}${MAKE_TOOL}${NC}"
  [[ "$QUIET" == true ]]  && echo -e "  静默模式:  ${GREEN}是${NC}"

  echo ""
  echo -e "  ${BOLD}完整命令:${NC}"
  echo -e "  ${YELLOW}${cmd}${NC}"
  echo ""
}

execute_command() {
  local cmd="$1"
  info "执行命令..."
  echo -e "  ${YELLOW}${cmd}${NC}\n"

  if eval "$cmd"; then
    echo ""
    info "${GREEN}rl-project create 执行成功${NC}"
    return 0
  else
    local rc=$?
    echo ""
    error "rl-project create 执行失败 (exit code: $rc)"
    return 1
  fi
}

# ============================================================================
# Help
# ============================================================================

show_help() {
  cat <<'HELP'
Usage:
  bash project_create.sh                    # 交互模式
  bash project_create.sh [OPTIONS]          # CLI 模式

交互式 SylixOS 工程创建脚本。
支持交互菜单和命令行参数两种方式。

CLI 参数:
  --name=NAME              工程名称 (必填，或从 --source 推断)
  --type=TYPE              构建类型 (必填)
                           可选: cmake, automake, realevo, python, cython,
                                 go, javascript, ros2
  --template=TEMPLATE      工程模板
                           可选: app, lib, ko, common, shared_lib
  --source=PATH_OR_URL     源码路径或 Git 仓库地址
  --branch=BRANCH          Git 分支名称 (需要 --source)
  --debug-level=LEVEL      构建级别 (debug|release)
  --make-tool=TOOL         构建工具 (make|ninja)
  --quiet                  跳过交互式配置文件选择
  --dry-run                仅显示命令，不执行
  --yes, --confirm         跳过确认，直接执行
  --help, -h               显示此帮助信息

工程名称推断:
  如果未提供 --name 但提供了 --source (Git URL)，
  将从 URL 的最后一段推断工程名称 (去除 .git 后缀)。

示例:
  bash project_create.sh --name=myapp --type=cmake --template=app --dry-run
  bash project_create.sh --type=cmake --template=ko --source=ssh://git@example.com/my-driver.git --dry-run
  bash project_create.sh --name=mylib --type=realevo --template=shared_lib --make-tool=make --yes
HELP
}

# ============================================================================
# Main
# ============================================================================

main() {
  parse_args "$@"

  if [[ "$CLI_MODE" == true ]]; then
    # --- CLI mode ---
    # Infer name from source if not provided
    infer_name_from_source

    # Check required params
    if ! check_required; then
      exit 1
    fi

    # Validate
    if ! validate_params; then
      exit 1
    fi
    info "参数校验通过"

    # Build command
    local cmd
    cmd=$(build_command)

    # Show summary
    show_summary "$cmd"

    # Dry-run: stop here
    if [[ "$DRY_RUN" == true ]]; then
      info "Dry-run 模式，不执行命令"
      exit 0
    fi

    # Confirm
    if [[ "$AUTO_CONFIRM" != true ]]; then
      read -rp "确认执行？[y/N] " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "已取消"
        exit 0
      fi
    fi

    if ! execute_command "$cmd"; then
      exit 1
    fi

    echo ""
    info "${GREEN}工程创建完成！${NC}"

  else
    # --- Interactive mode ---
    echo -e "${BOLD}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   SylixOS 工程创建交互向导                ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════╝${NC}"

    collect_interactive_params

    # Validate
    if ! validate_params; then
      error "请修正上述错误后重新运行脚本"
      exit 1
    fi
    info "参数校验通过"

    # Build command
    local cmd
    cmd=$(build_command)

    # Show summary
    show_summary "$cmd"

    # Confirm and execute
    read -rp "确认执行？[y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      info "已取消"
      exit 0
    fi

    if ! execute_command "$cmd"; then
      exit 1
    fi

    echo ""
    info "${GREEN}工程创建完成！${NC}"
  fi
}

main "$@"
