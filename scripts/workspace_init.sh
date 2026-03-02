#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# workspace_init.sh — SylixOS workspace initialization
#
# Two usage modes:
#   Interactive:  bash workspace_init.sh
#   CLI (Claude): bash workspace_init.sh --mode=prepared-base --platform=ARM_A7 ...
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

# --- Platform data ---
declare -A ARCH_PLATFORMS
ARCH_PLATFORMS=(
  [ARM]="ARM_926H ARM_926S ARM_920T ARM_A5 ARM_A5_SOFT ARM_A7 ARM_A7_SOFT ARM_A8 ARM_A8_SOFT ARM_A9 ARM_A9_SOFT ARM_A15 ARM_A15_SOFT ARM_V7A ARM_V7A_SOFT"
  [ARM64]="ARM64_A53 ARM64_A55 ARM64_A57 ARM64_A72 ARM64_GENERIC"
  [MIPS]="MIPS32 MIPS32_SOFT MIPS32_R2 MIPS32_R2_SOFT MIPS64_R2 MIPS64_R2_SOFT MIPS64_LS3A MIPS64_LS3A_SOFT"
  [X86]="x86_PENTIUM x86_PENTIUM_SOFT X86_64"
  [PPC]="PPC_750 PPC_750_SOFT PPC_464FP PPC_464FP_SOFT PPC_E500V1 PPC_E500V1_SOFT PPC_E500V2 PPC_E500V2_SOFT PPC_E500MC PPC_E500MC_SOFT PPC_E5500 PPC_E5500_SOFT PPC_E6500 PPC_E6500_SOFT"
  [SPARC]="SPARC_LEON3 SPARC_LEON3_SOFT SPARC_V8 SPARC_V8_SOFT"
  [RISCV]="RISCV_GC32 RISCV_GC32_SOFT RISCV_GC64 RISCV_GC64_SOFT"
  [LOONGARCH]="LOONGARCH64 LOONGARCH64_SOFT"
  [CSKY]="CSKY_CK807 CSKY_CK807_SOFT CSKY_CK810 CSKY_CK810_SOFT CSKY_CK860 CSKY_CK860_SOFT"
  [SW]="SW6B SW6B_SOFT"
)
ARCH_ORDER=(ARM ARM64 MIPS X86 PPC SPARC RISCV LOONGARCH CSKY SW)

LTS_COMPILED_PLATFORMS="ARM_920T ARM_V7A ARM64_GENERIC PPC_E500MC PPC_E5500 PPC_750 LOONGARCH64 MIPS32_R2 MIPS64_LS3A x86_PENTIUM X86_64 RISCV_GC64 PPC_E500V2 SPARC_LEON3 CSKY_CK810"
LINUX_PLATFORMS="ARM64 X86"

VERSIONS=("default" "ecs_3.6.5" "lts_3.6.5" "lts_3.6.5_compiled")
VERSION_LABELS=("default — 默认版本" "ecs_3.6.5 — ECS 3.6.5" "lts_3.6.5 — LTS 3.6.5 (需要编译)" "lts_3.6.5_compiled — LTS 3.6.5 预编译版 (仅支持部分平台)")

RESEARCH_REPO_DEFAULT="ssh://git@10.7.100.21:16783/sylixos/research/libsylixos.git"

# --- Collected parameters (global) ---
MODE=""
PLATFORM=""
VERSION=""
DEBUG_LEVEL=""
CREATEBASE=""
BUILD=""
BASE_PATH=""
PRODUCT=""
LINUX_PLATFORM=""
TOOLCHAIN=""
WORKSPACE_DIR=""
RESEARCH_REPO=""
RESEARCH_BRANCH=""
CUSTOM_ARGS=""

# --- Flags ---
CLI_MODE=false
DRY_RUN=false
AUTO_CONFIRM=false

# ============================================================================
# CLI argument parsing
# ============================================================================

parse_args() {
  # If no args (or only --help), stay in interactive mode
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
      --mode=*)
        MODE="${arg#*=}"
        CLI_MODE=true
        ;;
      --platform=*)
        PLATFORM="${arg#*=}"
        CLI_MODE=true
        ;;
      --version=*)
        VERSION="${arg#*=}"
        CLI_MODE=true
        ;;
      --debug_level=*)
        DEBUG_LEVEL="${arg#*=}"
        CLI_MODE=true
        ;;
      --createbase=*)
        CREATEBASE="${arg#*=}"
        CLI_MODE=true
        ;;
      --build=*)
        BUILD="${arg#*=}"
        CLI_MODE=true
        ;;
      --base=*)
        BASE_PATH="${arg#*=}"
        CLI_MODE=true
        ;;
      --product=*)
        PRODUCT="${arg#*=}"
        CLI_MODE=true
        ;;
      --linux_platform=*)
        LINUX_PLATFORM="${arg#*=}"
        CLI_MODE=true
        ;;
      --toolchain=*)
        TOOLCHAIN="${arg#*=}"
        CLI_MODE=true
        ;;
      --workspace=*)
        WORKSPACE_DIR="${arg#*=}"
        CLI_MODE=true
        ;;
      --research_repo=*)
        RESEARCH_REPO="${arg#*=}"
        CLI_MODE=true
        ;;
      --research_branch=*)
        RESEARCH_BRANCH="${arg#*=}"
        CLI_MODE=true
        ;;
      --custom_args=*)
        CUSTOM_ARGS="${arg#*=}"
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

# Apply defaults for CLI mode based on the selected mode
apply_defaults() {
  case "$MODE" in
    product)
      # product requires only --product
      ;;
    prepared-base)
      [[ -z "$DEBUG_LEVEL" ]] && DEBUG_LEVEL="release"
      [[ -z "$CREATEBASE" ]]  && CREATEBASE="true"
      [[ -z "$BUILD" ]]       && BUILD="false"
      ;;
    research-base)
      # Forced values
      VERSION="default"
      CREATEBASE="true"
      BUILD="false"
      [[ -z "$DEBUG_LEVEL" ]]    && DEBUG_LEVEL="release"
      [[ -z "$RESEARCH_REPO" ]]  && RESEARCH_REPO="$RESEARCH_REPO_DEFAULT"
      ;;
    existing-base)
      [[ -z "$DEBUG_LEVEL" ]] && DEBUG_LEVEL="release"
      [[ -z "$BUILD" ]]       && BUILD="false"
      ;;
    linux)
      # linux_platform and toolchain are required, no defaults
      ;;
    custom)
      # custom_args pass-through
      ;;
  esac
}

# Check that required params are present for CLI mode
check_required() {
  local missing=()

  case "$MODE" in
    product)
      [[ -z "$PRODUCT" ]] && missing+=("--product")
      ;;
    prepared-base)
      [[ -z "$VERSION" ]]  && missing+=("--version")
      [[ -z "$PLATFORM" ]] && missing+=("--platform")
      ;;
    research-base)
      [[ -z "$PLATFORM" ]] && missing+=("--platform")
      ;;
    existing-base)
      [[ -z "$BASE_PATH" ]] && missing+=("--base")
      [[ -z "$PLATFORM" ]]  && missing+=("--platform")
      ;;
    linux)
      [[ -z "$LINUX_PLATFORM" ]] && missing+=("--linux_platform")
      [[ -z "$TOOLCHAIN" ]]      && missing+=("--toolchain")
      ;;
    custom)
      [[ -z "$CUSTOM_ARGS" ]] && missing+=("--custom_args")
      ;;
    "")
      missing+=("--mode")
      ;;
  esac

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "缺少必填参数: ${missing[*]}"
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

select_bool() {
  local prompt="$1"
  local default="${2:-true}"
  select_from_list "$prompt" "true" "false"
  if [[ $REPLY -eq 0 ]]; then
    echo "true"
  else
    echo "false"
  fi
}

input_path() {
  local prompt="$1"
  local required="${2:-true}"
  local check_exists="${3:-false}"

  echo -e "\n${BOLD}${prompt}${NC}"
  if [[ "$required" == "false" ]]; then
    echo -e "  (可选，直接回车跳过)"
  fi

  while true; do
    read -rp "> " path
    if [[ -z "$path" && "$required" == "false" ]]; then
      echo ""
      return 0
    fi
    if [[ -z "$path" ]]; then
      error "路径不能为空"
      continue
    fi
    if [[ "$check_exists" == "true" && ! -e "$path" ]]; then
      warn "路径不存在: $path"
      read -rp "是否继续使用此路径？[y/N] " yn
      if [[ "$yn" =~ ^[Yy]$ ]]; then
        echo "$path"
        return 0
      fi
      continue
    fi
    echo "$path"
    return 0
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
# Interactive selection functions
# ============================================================================

select_mode() {
  header "选择初始化模式"
  local modes=(
    "product         — 基于产品系列初始化"
    "prepared-base   — 使用预编译 Base 初始化 (最常用)"
    "research-base   — 内核研究/开发模式"
    "existing-base   — 使用已有 Base 目录"
    "linux           — Linux 交叉编译工作空间"
    "custom          — 自定义参数"
  )
  select_from_list "请选择初始化模式：" "${modes[@]}"
  case $REPLY in
    0) MODE="product" ;;
    1) MODE="prepared-base" ;;
    2) MODE="research-base" ;;
    3) MODE="existing-base" ;;
    4) MODE="linux" ;;
    5) MODE="custom" ;;
  esac
  info "已选择模式: ${GREEN}${MODE}${NC}"
}

select_arch_family() {
  header "选择架构族"
  local families=()
  for arch in "${ARCH_ORDER[@]}"; do
    families+=("$arch")
  done
  select_from_list "请选择架构族：" "${families[@]}"
  echo "${ARCH_ORDER[$REPLY]}"
}

select_platform() {
  local arch
  arch=$(select_arch_family)

  header "选择平台 (${arch})"
  local plats
  read -ra plats <<< "${ARCH_PLATFORMS[$arch]}"
  select_from_list "请选择具体平台：" "${plats[@]}"
  PLATFORM="${plats[$REPLY]}"
  info "已选择平台: ${GREEN}${PLATFORM}${NC}"
}

select_multi_platform() {
  local platforms=()
  while true; do
    select_platform
    platforms+=("$PLATFORM")
    echo ""
    read -rp "是否继续添加平台？[y/N] " more
    if [[ ! "$more" =~ ^[Yy]$ ]]; then
      break
    fi
  done
  PLATFORM=$(IFS=:; echo "${platforms[*]}")
  info "最终平台列表: ${GREEN}${PLATFORM}${NC}"
}

select_version() {
  header "选择 Base 版本"
  select_from_list "请选择版本：" "${VERSION_LABELS[@]}"
  VERSION="${VERSIONS[$REPLY]}"
  info "已选择版本: ${GREEN}${VERSION}${NC}"
}

select_debug_level() {
  header "选择构建级别"
  select_from_list "请选择 debug_level：" "debug" "release"
  if [[ $REPLY -eq 0 ]]; then
    DEBUG_LEVEL="debug"
  else
    DEBUG_LEVEL="release"
  fi
  info "已选择: ${GREEN}${DEBUG_LEVEL}${NC}"
}

# ============================================================================
# Interactive mode-specific parameter collection
# ============================================================================

collect_product_params() {
  header "Product 模式参数"
  PRODUCT=$(input_text "请输入产品系列名称 (product)：")
}

collect_prepared_base_params() {
  header "Prepared-Base 模式参数"
  select_version
  select_multi_platform
  select_debug_level

  echo ""
  CREATEBASE=$(select_bool "是否创建 Base 工程 (createbase)？" "true")
  info "createbase: ${GREEN}${CREATEBASE}${NC}"

  BUILD=$(select_bool "是否编译 Base (build)？" "true")
  info "build: ${GREEN}${BUILD}${NC}"

  BASE_PATH=$(input_path "请输入 Base 路径 (base)：" "false" "false")
  if [[ -n "$BASE_PATH" ]]; then
    info "base: ${GREEN}${BASE_PATH}${NC}"
  fi
}

collect_research_base_params() {
  header "Research-Base 模式参数"
  warn "此模式强制: version=default, createbase=true, build=false"

  VERSION="default"
  CREATEBASE="true"
  BUILD="false"

  select_platform
  select_debug_level

  BASE_PATH=$(input_path "请输入 Base 路径 (base)：" "false" "false")
  if [[ -n "$BASE_PATH" ]]; then
    info "base: ${GREEN}${BASE_PATH}${NC}"
  fi

  echo -e "\n${BOLD}Research 仓库配置${NC}"
  echo -e "  默认仓库: ${RESEARCH_REPO_DEFAULT}"
  read -rp "是否使用默认仓库？[Y/n] " use_default
  if [[ "$use_default" =~ ^[Nn]$ ]]; then
    RESEARCH_REPO=$(input_text "请输入 Git 仓库地址：")
  else
    RESEARCH_REPO="$RESEARCH_REPO_DEFAULT"
  fi
  info "research_repo: ${GREEN}${RESEARCH_REPO}${NC}"

  RESEARCH_BRANCH=$(input_text "请输入要 checkout 的分支名称：" "false")
  if [[ -n "$RESEARCH_BRANCH" ]]; then
    info "research_branch: ${GREEN}${RESEARCH_BRANCH}${NC}"
  fi
}

collect_existing_base_params() {
  header "Existing-Base 模式参数"
  BASE_PATH=$(input_path "请输入已有 Base 路径：" "true" "true")
  info "base: ${GREEN}${BASE_PATH}${NC}"

  select_platform
  select_debug_level

  BUILD=$(select_bool "是否编译 Base (build)？通常选 false" "false")
  info "build: ${GREEN}${BUILD}${NC}"
}

collect_linux_params() {
  header "Linux 模式参数"
  select_from_list "请选择 Linux 平台：" "ARM64" "X86"
  if [[ $REPLY -eq 0 ]]; then
    LINUX_PLATFORM="ARM64"
  else
    LINUX_PLATFORM="X86"
  fi
  info "linux_platform: ${GREEN}${LINUX_PLATFORM}${NC}"

  TOOLCHAIN=$(input_path "请输入 toolchain CMake 文件路径：" "true" "true")
  info "toolchain: ${GREEN}${TOOLCHAIN}${NC}"
}

collect_custom_params() {
  header "Custom 模式参数"
  echo "请输入要传递给 rl-workspace init 的完整参数："
  echo "例如: --version=default --platform=ARM_V7A --createbase=true --build=true"
  read -rp "> " CUSTOM_ARGS
}

# ============================================================================
# Validation
# ============================================================================

validate_params() {
  local errors=()

  # Validate platform exists in known list (skip for product/linux/custom)
  if [[ "$MODE" == "prepared-base" || "$MODE" == "research-base" || "$MODE" == "existing-base" ]]; then
    IFS=':' read -ra plat_list <<< "$PLATFORM"
    local all_platforms=""
    for arch in "${ARCH_ORDER[@]}"; do
      all_platforms+=" ${ARCH_PLATFORMS[$arch]}"
    done
    for p in "${plat_list[@]}"; do
      if [[ ! " $all_platforms " =~ " $p " ]]; then
        errors+=("未知平台: $p")
      fi
    done
  fi

  # lts_3.6.5_compiled constraint
  if [[ "$VERSION" == "lts_3.6.5_compiled" ]]; then
    IFS=':' read -ra plat_list <<< "$PLATFORM"
    for p in "${plat_list[@]}"; do
      if [[ ! " $LTS_COMPILED_PLATFORMS " =~ " $p " ]]; then
        errors+=("平台 $p 不支持 lts_3.6.5_compiled 版本。支持的平台: $LTS_COMPILED_PLATFORMS")
      fi
    done
  fi

  # linux mode validation
  if [[ "$MODE" == "linux" ]]; then
    if [[ ! " $LINUX_PLATFORMS " =~ " $LINUX_PLATFORM " ]]; then
      errors+=("Linux 平台必须是 ARM64 或 X86，当前: $LINUX_PLATFORM")
    fi
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
# Command building
# ============================================================================

build_command() {
  local cmd="rl-workspace init"

  case "$MODE" in
    product)
      cmd+=" --product=${PRODUCT}"
      ;;
    prepared-base)
      cmd+=" --version=${VERSION}"
      cmd+=" --platform=${PLATFORM}"
      cmd+=" --createbase=${CREATEBASE}"
      cmd+=" --build=${BUILD}"
      cmd+=" --debug_level=${DEBUG_LEVEL}"
      [[ -n "$BASE_PATH" ]] && cmd+=" --base=${BASE_PATH}"
      ;;
    research-base)
      cmd+=" --version=default"
      cmd+=" --platform=${PLATFORM}"
      cmd+=" --createbase=true"
      cmd+=" --build=false"
      cmd+=" --debug_level=${DEBUG_LEVEL}"
      [[ -n "$BASE_PATH" ]] && cmd+=" --base=${BASE_PATH}"
      ;;
    existing-base)
      cmd+=" --base=${BASE_PATH}"
      cmd+=" --platform=${PLATFORM}"
      [[ -n "$BUILD" ]] && cmd+=" --build=${BUILD}"
      [[ -n "$DEBUG_LEVEL" ]] && cmd+=" --debug_level=${DEBUG_LEVEL}"
      ;;
    linux)
      cmd+=" --os=linux"
      cmd+=" --linux_platform=${LINUX_PLATFORM}"
      cmd+=" --toolchain=${TOOLCHAIN}"
      ;;
    custom)
      cmd+=" ${CUSTOM_ARGS}"
      ;;
  esac

  echo "$cmd"
}

# ============================================================================
# Summary & execution
# ============================================================================

show_summary() {
  local cmd="$1"

  header "命令预览 (Dry Run)"
  echo ""
  echo -e "  模式:    ${GREEN}${MODE}${NC}"

  case "$MODE" in
    product)
      echo -e "  产品:    ${GREEN}${PRODUCT}${NC}"
      ;;
    prepared-base)
      echo -e "  版本:    ${GREEN}${VERSION}${NC}"
      echo -e "  平台:    ${GREEN}${PLATFORM}${NC}"
      echo -e "  构建级别: ${GREEN}${DEBUG_LEVEL}${NC}"
      echo -e "  创建Base: ${GREEN}${CREATEBASE}${NC}"
      echo -e "  编译Base: ${GREEN}${BUILD}${NC}"
      [[ -n "$BASE_PATH" ]] && echo -e "  Base路径: ${GREEN}${BASE_PATH}${NC}"
      ;;
    research-base)
      echo -e "  版本:    ${GREEN}default${NC} (强制)"
      echo -e "  平台:    ${GREEN}${PLATFORM}${NC}"
      echo -e "  构建级别: ${GREEN}${DEBUG_LEVEL}${NC}"
      echo -e "  创建Base: ${GREEN}true${NC} (强制)"
      echo -e "  编译Base: ${GREEN}false${NC} (强制)"
      [[ -n "$BASE_PATH" ]] && echo -e "  Base路径: ${GREEN}${BASE_PATH}${NC}"
      echo -e "  研究仓库: ${GREEN}${RESEARCH_REPO}${NC}"
      [[ -n "$RESEARCH_BRANCH" ]] && echo -e "  研究分支: ${GREEN}${RESEARCH_BRANCH}${NC}"
      ;;
    existing-base)
      echo -e "  Base路径: ${GREEN}${BASE_PATH}${NC}"
      echo -e "  平台:    ${GREEN}${PLATFORM}${NC}"
      [[ -n "$BUILD" ]] && echo -e "  编译Base: ${GREEN}${BUILD}${NC}"
      [[ -n "$DEBUG_LEVEL" ]] && echo -e "  构建级别: ${GREEN}${DEBUG_LEVEL}${NC}"
      ;;
    linux)
      echo -e "  平台:    ${GREEN}${LINUX_PLATFORM}${NC}"
      echo -e "  Toolchain: ${GREEN}${TOOLCHAIN}${NC}"
      ;;
    custom)
      echo -e "  自定义参数: ${GREEN}${CUSTOM_ARGS}${NC}"
      ;;
  esac

  echo ""
  echo -e "  ${BOLD}完整命令:${NC}"
  echo -e "  ${YELLOW}${cmd}${NC}"

  if [[ "$MODE" == "research-base" ]]; then
    echo ""
    echo -e "  ${BOLD}后处理步骤:${NC}"
    echo -e "  1. 删除默认 libsylixos 目录"
    echo -e "  2. 克隆研究仓库: ${RESEARCH_REPO}"
    [[ -n "$RESEARCH_BRANCH" ]] && echo -e "  3. Checkout 分支: ${RESEARCH_BRANCH}"
    echo -e "  4. 修改 Makefile (SUBDIR 仅保留 libsylixos + libcextern, all 目标 make 加 -j16)"
  fi

  echo ""
}

execute_command() {
  local cmd="$1"
  info "执行命令..."
  echo -e "  ${YELLOW}${cmd}${NC}\n"

  if eval "$cmd"; then
    echo ""
    info "${GREEN}rl-workspace init 执行成功${NC}"
    return 0
  else
    local rc=$?
    echo ""
    error "rl-workspace init 执行失败 (exit code: $rc)"
    return 1
  fi
}

# ============================================================================
# Research-base post-init processing
# ============================================================================

research_post_init() {
  local ws="${WORKSPACE_DIR:-.}"
  local base_dir="${ws}/.realevo/base"
  local libsylixos_dir="${base_dir}/libsylixos"

  header "Research-Base 后处理"

  # Step 1: Remove default libsylixos
  info "步骤 1/4: 删除默认 libsylixos 目录"
  if [[ -d "$libsylixos_dir" ]]; then
    rm -rf "$libsylixos_dir"
    info "已删除: ${libsylixos_dir}"
  else
    warn "目录不存在，跳过: ${libsylixos_dir}"
  fi

  # Step 2: Clone research repo
  info "步骤 2/4: 克隆研究仓库"
  echo -e "  ${YELLOW}git clone ${RESEARCH_REPO} ${libsylixos_dir}${NC}"
  if ! git clone "$RESEARCH_REPO" "$libsylixos_dir"; then
    error "git clone 失败"
    return 1
  fi

  # Step 3: Checkout branch if specified
  if [[ -n "$RESEARCH_BRANCH" ]]; then
    info "步骤 3/4: Checkout 分支 ${RESEARCH_BRANCH}"
    if ! (cd "$libsylixos_dir" && git checkout "$RESEARCH_BRANCH"); then
      error "git checkout 失败"
      return 1
    fi
  else
    info "步骤 3/4: 未指定分支，跳过"
  fi

  # Step 4: Patch Makefile
  info "步骤 4/4: 修改 Makefile"
  local makefile="${base_dir}/Makefile"
  if [[ ! -f "$makefile" ]]; then
    error "Makefile 不存在: ${makefile}"
    return 1
  fi

  # 4a: SUBDIR only keep libsylixos + libcextern
  sed -i 's/^\(SUBDIR[[:space:]]*=[[:space:]]*\).*/\1libsylixos libcextern/' "$makefile"
  info "已修改 SUBDIR 为: libsylixos libcextern"

  # 4b: all target — add -j16 to make commands
  sed -i '/^all:/,/^[^\t]/ s/\([\t].*\)make\b/\1make -j16/' "$makefile"
  info "已在 all 目标的 make 命令后添加 -j16"

  echo ""
  info "${GREEN}Research-Base 后处理完成${NC}"
}

# ============================================================================
# Help
# ============================================================================

show_help() {
  cat <<'HELP'
Usage:
  bash workspace_init.sh                    # 交互模式
  bash workspace_init.sh [OPTIONS]          # CLI 模式

交互式 SylixOS workspace 初始化脚本。
支持交互菜单和命令行参数两种方式。

模式 (--mode):
  product        基于产品系列初始化
  prepared-base  使用预编译 Base 初始化 (最常用)
  research-base  内核研究/开发模式
  existing-base  使用已有 Base 目录
  linux          Linux 交叉编译工作空间
  custom         自定义参数

CLI 参数:
  --mode=MODE              初始化模式 (必填)
  --platform=PLATFORM      目标平台，多平台用 : 分隔
  --version=VERSION        Base 版本 (default|ecs_3.6.5|lts_3.6.5|lts_3.6.5_compiled)
  --debug_level=LEVEL      构建级别 (debug|release)，默认 debug
  --createbase=BOOL        是否创建 Base (true|false)
  --build=BOOL             是否编译 Base (true|false)
  --base=PATH              Base 路径
  --product=NAME           产品系列名 (product 模式)
  --linux_platform=ARCH    Linux 平台 (ARM64|X86)
  --toolchain=PATH         Toolchain CMake 文件路径
  --workspace=DIR          工作空间目录
  --research_repo=URL      研究仓库地址
  --research_branch=BRANCH 研究分支名称
  --custom_args=ARGS       自定义参数 (custom 模式)
  --dry-run                仅显示命令，不执行
  --yes, --confirm         跳过确认，直接执行
  --help, -h               显示此帮助信息

示例:
  bash workspace_init.sh --mode=prepared-base --platform=ARM_A7 --version=default
  bash workspace_init.sh --mode=prepared-base --platform=ARM_A7 --version=default --yes
  bash workspace_init.sh --mode=linux --linux_platform=ARM64 --toolchain=/path/to/toolchain.cmake --dry-run
HELP
}

# ============================================================================
# Main
# ============================================================================

main() {
  parse_args "$@"

  if [[ "$CLI_MODE" == true ]]; then
    # --- CLI mode ---
    # Apply defaults for the selected mode
    apply_defaults

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

    # Change to workspace directory if specified
    if [[ -n "$WORKSPACE_DIR" ]]; then
      mkdir -p "$WORKSPACE_DIR"
      cd "$WORKSPACE_DIR"
    fi

    if ! execute_command "$cmd"; then
      exit 1
    fi

    # Research-base post-init
    if [[ "$MODE" == "research-base" ]]; then
      research_post_init
    fi

    echo ""
    info "${GREEN}Workspace 初始化完成！${NC}"

  else
    # --- Interactive mode ---
    echo -e "${BOLD}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   SylixOS Workspace 初始化交互向导        ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════╝${NC}"

    # Step 1: Select mode
    select_mode

    # Step 2: Collect parameters based on mode
    case "$MODE" in
      product)       collect_product_params ;;
      prepared-base) collect_prepared_base_params ;;
      research-base) collect_research_base_params ;;
      existing-base) collect_existing_base_params ;;
      linux)         collect_linux_params ;;
      custom)        collect_custom_params ;;
    esac

    # Step 3: Ask for workspace directory
    if [[ "$MODE" != "custom" ]]; then
      WORKSPACE_DIR=$(input_path "请输入 workspace 目录 (工作空间将在此目录中创建)：" "false" "false")
      if [[ -n "$WORKSPACE_DIR" ]]; then
        info "workspace: ${GREEN}${WORKSPACE_DIR}${NC}"
      fi
    fi

    # Step 4: Validate
    if ! validate_params; then
      error "请修正上述错误后重新运行脚本"
      exit 1
    fi
    info "参数校验通过"

    # Step 5: Build command
    local cmd
    cmd=$(build_command)

    # Step 6: Show summary
    show_summary "$cmd"

    # Step 7: Confirm and execute
    read -rp "确认执行？[y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      info "已取消"
      exit 0
    fi

    # Change to workspace directory if specified
    if [[ -n "$WORKSPACE_DIR" ]]; then
      mkdir -p "$WORKSPACE_DIR"
      cd "$WORKSPACE_DIR"
    fi

    if ! execute_command "$cmd"; then
      exit 1
    fi

    # Step 8: Research-base post-init
    if [[ "$MODE" == "research-base" ]]; then
      echo ""
      read -rp "是否执行 research-base 后处理步骤？[Y/n] " do_post
      if [[ ! "$do_post" =~ ^[Nn]$ ]]; then
        research_post_init
      fi
    fi

    echo ""
    info "${GREEN}Workspace 初始化完成！${NC}"
  fi
}

main "$@"
