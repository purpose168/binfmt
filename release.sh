#!/usr/bin/env bash

# Git 发布脚本
# 功能：版本号更新、CHANGELOG生成、代码构建、测试、提交、标签创建和推送
# 日期：2026-01-05

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"
VERSION_FILE=""
CHANGELOG_FILE="${PROJECT_ROOT}/CHANGELOG.md"
BACKUP_DIR="${PROJECT_ROOT}/.release_backup"
CURRENT_VERSION=""
NEW_VERSION=""
VERSION_TYPE=""
CUSTOM_VERSION=""
RELEASE_NOTES=""
DRY_RUN=false
SKIP_BUILD=false
SKIP_TEST=false
SKIP_CHANGELOG=false
REMOTE_NAME="origin"
BRANCH_NAME="master"
BACKUP_CREATED=false
TAG_CREATED=false
COMMIT_CREATED=false

# 帮助信息
show_help() {
    cat << EOF
${BLUE}Git 发布脚本${NC}

${GREEN}用法:${NC}
    $0 [选项]

${GREEN}选项:${NC}
    -t, --type <TYPE>          版本类型：major, minor, patch（必需，除非使用 -v）
    -v, --version <VERSION>    自定义版本号（例如：1.2.3）
    -n, --notes <NOTES>        发布说明（多行使用 \\n 分隔）
    -r, --remote <NAME>        远程仓库名称（默认：origin）
    -b, --branch <NAME>        分支名称（默认：master）
    --dry-run                  试运行模式，不实际执行
    --skip-build               跳过构建步骤
    --skip-test                跳过测试步骤
    --skip-changelog           跳过 CHANGELOG 生成
    -h, --help                 显示此帮助信息

${GREEN}示例:${NC}
    # 发布补丁版本（1.0.0 -> 1.0.1）
    $0 --type patch

    # 发布次版本（1.0.0 -> 1.1.0）
    $0 --type minor

    # 发布主版本（1.0.0 -> 2.0.0）
    $0 --type major

    # 使用自定义版本号
    $0 --version 2.5.0

    # 添加发布说明
    $0 --type patch --notes "修复了几个bug\\n优化了性能"

    # 试运行模式
    $0 --type patch --dry-run

    # 跳过构建和测试
    $0 --type patch --skip-build --skip-test

${GREEN}功能说明:${NC}
    1. 版本号更新：支持 major/minor/patch 三种版本类型
    2. CHANGELOG 生成：自动生成更新日志
    3. 代码构建：执行 docker buildx bake
    4. 单元测试：运行 lint、validate-vendor、install-and-test
    5. Git 提交：提交版本更新和 CHANGELOG
    6. 标签创建：创建 Git 标签
    7. 远程推送：推送提交和标签到远程仓库
    8. 错误回滚：失败时自动回滚操作

${GREEN}错误处理:${NC}
    脚本在任一环节失败时会自动回滚已执行的操作，包括：
    - 删除已创建的 Git 标签
    - 回滚 Git 提交
    - 恢复备份的文件

EOF
}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 '$1' 未找到，请先安装"
        return 1
    fi
    return 0
}

# 检查必要的命令
check_prerequisites() {
    log_info "检查必要的环境和工具..."

    local missing_commands=()

    check_command git || missing_commands+=("git")
    check_command docker || missing_commands+=("docker")
    check_command jq || missing_commands+=("jq")

    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "缺少必要的命令: ${missing_commands[*]}"
        return 1
    fi

    log_success "所有必要的工具都已安装"
    return 0
}

# 检查 Git 仓库状态
check_git_status() {
    log_info "检查 Git 仓库状态..."

    if [ ! -d "${PROJECT_ROOT}/.git" ]; then
        log_error "当前目录不是一个 Git 仓库"
        return 1
    fi

    cd "${PROJECT_ROOT}"

    # 检查是否有未提交的更改
    if [ -n "$(git status --porcelain)" ]; then
        log_error "工作目录有未提交的更改"
        git status --short
        return 1
    fi

    # 检查当前分支
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" != "$BRANCH_NAME" ]; then
        log_warning "当前分支是 '$current_branch'，发布分支是 '$BRANCH_NAME'"
        read -p "是否继续？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    # 检查远程仓库
    if ! git remote | grep -q "^${REMOTE_NAME}$"; then
        log_error "远程仓库 '${REMOTE_NAME}' 不存在"
        return 1
    fi

    # 检查远程更新
    log_info "检查远程更新..."
    git fetch "${REMOTE_NAME}" "${BRANCH_NAME}" > /dev/null 2>&1

    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse "${REMOTE_NAME}/${BRANCH_NAME}")

    if [ "$local_commit" != "$remote_commit" ]; then
        log_error "本地分支与远程分支不同步"
        log_info "请先拉取远程更新: git pull ${REMOTE_NAME} ${BRANCH_NAME}"
        return 1
    fi

    log_success "Git 仓库状态检查通过"
    return 0
}

# 查找版本文件
find_version_file() {
    log_info "查找版本文件..."

    # 检查常见的版本文件位置
    local possible_files=(
        "VERSION"
        "version.txt"
        ".version"
        "VERSION.txt"
    )

    for file in "${possible_files[@]}"; do
        if [ -f "${PROJECT_ROOT}/${file}" ]; then
            VERSION_FILE="${PROJECT_ROOT}/${file}"
            log_success "找到版本文件: $file"
            return 0
        fi
    done

    # 如果没有找到版本文件，尝试从 git 标签获取
    log_warning "未找到版本文件，将从 Git 标签获取版本信息"
    return 0
}

# 获取当前版本号
get_current_version() {
    log_info "获取当前版本号..."

    if [ -n "$VERSION_FILE" ] && [ -f "$VERSION_FILE" ]; then
        CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
        log_success "从文件读取版本: $CURRENT_VERSION"
    else
        # 从 git 标签获取
        local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
        CURRENT_VERSION=$(echo "$latest_tag" | sed 's/^v//')
        log_success "从 Git 标签读取版本: $CURRENT_VERSION"
    fi

    # 验证版本号格式
    if ! [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "版本号格式无效: $CURRENT_VERSION"
        return 1
    fi

    return 0
}

# 计算新版本号
calculate_new_version() {
    log_info "计算新版本号..."

    if [ -n "$CUSTOM_VERSION" ]; then
        # 使用自定义版本号
        NEW_VERSION="$CUSTOM_VERSION"
        log_info "使用自定义版本号: $NEW_VERSION"
    else
        # 根据版本类型计算
        local major=$(echo "$CURRENT_VERSION" | cut -d. -f1)
        local minor=$(echo "$CURRENT_VERSION" | cut -d. -f2)
        local patch=$(echo "$CURRENT_VERSION" | cut -d. -f3)

        case "$VERSION_TYPE" in
            major)
                major=$((major + 1))
                minor=0
                patch=0
                ;;
            minor)
                minor=$((minor + 1))
                patch=0
                ;;
            patch)
                patch=$((patch + 1))
                ;;
            *)
                log_error "无效的版本类型: $VERSION_TYPE"
                return 1
                ;;
        esac

        NEW_VERSION="${major}.${minor}.${patch}"
        log_success "计算新版本号: $CURRENT_VERSION -> $NEW_VERSION"
    fi

    # 验证新版本号格式
    if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "新版本号格式无效: $NEW_VERSION"
        return 1
    fi

    return 0
}

# 更新版本文件
update_version_file() {
    log_info "更新版本文件..."

    if [ -n "$VERSION_FILE" ] && [ -f "$VERSION_FILE" ]; then
        echo "$NEW_VERSION" > "$VERSION_FILE"
        log_success "版本文件已更新: $VERSION_FILE"
    else
        log_info "创建版本文件: VERSION"
        echo "$NEW_VERSION" > "${PROJECT_ROOT}/VERSION"
        VERSION_FILE="${PROJECT_ROOT}/VERSION"
        log_success "版本文件已创建"
    fi
}

# 生成 CHANGELOG
generate_changelog() {
    if [ "$SKIP_CHANGELOG" = true ]; then
        log_info "跳过 CHANGELOG 生成"
        return 0
    fi

    log_info "生成 CHANGELOG..."

    local tag_name="v${CURRENT_VERSION}"
    local changelog_entry=""

    # 获取上一个标签
    local previous_tag=$(git describe --tags --abbrev=0 "${tag_name}^" 2>/dev/null || echo "")

    # 获取提交日志
    if [ -n "$previous_tag" ]; then
        log_info "获取 ${previous_tag} 到 ${tag_name} 的提交..."
        local commits=$(git log --pretty=format:"- %s" "${previous_tag}..HEAD" 2>/dev/null || echo "")
    else
        log_info "获取所有提交..."
        local commits=$(git log --pretty=format:"- %s" HEAD 2>/dev/null || echo "")
    fi

    # 生成 CHANGELOG 条目
    local date=$(date +%Y-%m-%d)
    changelog_entry="## [${NEW_VERSION}] - ${date}"

    if [ -n "$RELEASE_NOTES" ]; then
        changelog_entry="${changelog_entry}

${RELEASE_NOTES}"
    fi

    if [ -n "$commits" ]; then
        changelog_entry="${changelog_entry}

### 变更

${commits}"
    fi

    # 更新 CHANGELOG 文件
    if [ -f "$CHANGELOG_FILE" ]; then
        # 备份现有 CHANGELOG
        cp "$CHANGELOG_FILE" "${BACKUP_DIR}/CHANGELOG.md.backup"

        # 在文件开头插入新条目
        {
            echo "$changelog_entry"
            echo ""
            cat "$CHANGELOG_FILE"
        } > "${CHANGELOG_FILE}.tmp"
        mv "${CHANGELOG_FILE}.tmp" "$CHANGELOG_FILE"

        log_success "CHANGELOG 已更新"
    else
        # 创建新的 CHANGELOG 文件
        {
            echo "# 更新日志"
            echo ""
            echo "$changelog_entry"
        } > "$CHANGELOG_FILE"

        log_success "CHANGELOG 已创建"
    fi

    return 0
}

# 执行代码构建
run_build() {
    if [ "$SKIP_BUILD" = true ]; then
        log_info "跳过构建步骤"
        return 0
    fi

    log_info "执行代码构建..."

    cd "${PROJECT_ROOT}"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] 将执行: docker buildx bake"
        return 0
    fi

    # 执行构建
    if ! docker buildx bake > /dev/null 2>&1; then
        log_error "构建失败"
        return 1
    fi

    log_success "代码构建成功"
    return 0
}

# 运行单元测试
run_tests() {
    if [ "$SKIP_TEST" = true ]; then
        log_info "跳过测试步骤"
        return 0
    fi

    log_info "运行单元测试..."

    cd "${PROJECT_ROOT}"

    local test_scripts=(
        "./hack/lint"
        "./hack/validate-vendor"
        "./hack/install-and-test"
    )

    for script in "${test_scripts[@]}"; do
        if [ ! -f "$script" ]; then
            log_warning "测试脚本不存在: $script"
            continue
        fi

        log_info "运行: $script"

        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] 将执行: $script"
            continue
        fi

        if ! bash "$script" > /dev/null 2>&1; then
            log_error "测试失败: $script"
            return 1
        fi
    done

    log_success "所有测试通过"
    return 0
}

# 创建备份
create_backup() {
    log_info "创建备份..."

    mkdir -p "$BACKUP_DIR"

    if [ -f "$VERSION_FILE" ]; then
        cp "$VERSION_FILE" "${BACKUP_DIR}/VERSION.backup"
    fi

    if [ -f "$CHANGELOG_FILE" ]; then
        cp "$CHANGELOG_FILE" "${BACKUP_DIR}/CHANGELOG.md.backup"
    fi

    BACKUP_CREATED=true
    log_success "备份已创建: $BACKUP_DIR"
}

# 恢复备份
restore_backup() {
    if [ "$BACKUP_CREATED" = false ]; then
        return 0
    fi

    log_warning "恢复备份..."

    if [ -f "${BACKUP_DIR}/VERSION.backup" ]; then
        cp "${BACKUP_DIR}/VERSION.backup" "$VERSION_FILE"
        log_info "已恢复版本文件"
    fi

    if [ -f "${BACKUP_DIR}/CHANGELOG.md.backup" ]; then
        cp "${BACKUP_DIR}/CHANGELOG.md.backup" "$CHANGELOG_FILE"
        log_info "已恢复 CHANGELOG"
    fi

    log_success "备份已恢复"
}

# 提交更改
commit_changes() {
    log_info "提交更改..."

    cd "${PROJECT_ROOT}"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] 将提交版本更新和 CHANGELOG"
        return 0
    fi

    local files_to_commit=()

    if [ -f "$VERSION_FILE" ]; then
        files_to_commit+=("$VERSION_FILE")
    fi

    if [ -f "$CHANGELOG_FILE" ]; then
        files_to_commit+=("$CHANGELOG_FILE")
    fi

    if [ ${#files_to_commit[@]} -eq 0 ]; then
        log_warning "没有文件需要提交"
        return 0
    fi

    git add "${files_to_commit[@]}"

    local commit_message="Release v${NEW_VERSION}"
    if [ -n "$RELEASE_NOTES" ]; then
        commit_message="${commit_message}

${RELEASE_NOTES}"
    fi

    git commit -m "$commit_message"

    COMMIT_CREATED=true
    log_success "更改已提交"
}

# 创建标签
create_tag() {
    log_info "创建 Git 标签..."

    cd "${PROJECT_ROOT}"

    local tag_name="v${NEW_VERSION}"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] 将创建标签: $tag_name"
        return 0
    fi

    # 检查标签是否已存在
    if git rev-parse "$tag_name" >/dev/null 2>&1; then
        log_error "标签已存在: $tag_name"
        return 1
    fi

    local tag_message="Release version ${NEW_VERSION}"
    if [ -n "$RELEASE_NOTES" ]; then
        tag_message="${tag_message}

${RELEASE_NOTES}"
    fi

    git tag -a "$tag_name" -m "$tag_message"

    TAG_CREATED=true
    log_success "标签已创建: $tag_name"
}

# 推送到远程仓库
push_to_remote() {
    log_info "推送到远程仓库..."

    cd "${PROJECT_ROOT}"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] 将推送提交和标签到 ${REMOTE_NAME}/${BRANCH_NAME}"
        return 0
    fi

    # 推送提交
    log_info "推送提交..."
    if ! git push "${REMOTE_NAME}" "${BRANCH_NAME}"; then
        log_error "推送提交失败"
        return 1
    fi

    # 推送标签
    log_info "推送标签..."
    if ! git push "${REMOTE_NAME}" "v${NEW_VERSION}"; then
        log_error "推送标签失败"
        return 1
    fi

    log_success "已推送到远程仓库"
}

# 回滚操作
rollback() {
    log_error "开始回滚操作..."

    cd "${PROJECT_ROOT}"

    # 删除标签
    if [ "$TAG_CREATED" = true ]; then
        log_warning "删除标签: v${NEW_VERSION}"
        git tag -d "v${NEW_VERSION}" 2>/dev/null || true
    fi

    # 回滚提交
    if [ "$COMMIT_CREATED" = true ]; then
        log_warning "回滚提交..."
        git reset --hard HEAD~1 2>/dev/null || true
    fi

    # 恢复备份
    restore_backup

    # 清理备份目录
    if [ -d "$BACKUP_DIR" ]; then
        rm -rf "$BACKUP_DIR"
    fi

    log_error "回滚完成"
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type)
                VERSION_TYPE="$2"
                shift 2
                ;;
            -v|--version)
                CUSTOM_VERSION="$2"
                shift 2
                ;;
            -n|--notes)
                RELEASE_NOTES="$2"
                shift 2
                ;;
            -r|--remote)
                REMOTE_NAME="$2"
                shift 2
                ;;
            -b|--branch)
                BRANCH_NAME="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-test)
                SKIP_TEST=true
                shift
                ;;
            --skip-changelog)
                SKIP_CHANGELOG=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 验证参数
    if [ -z "$VERSION_TYPE" ] && [ -z "$CUSTOM_VERSION" ]; then
        log_error "必须指定 --type 或 --version"
        show_help
        exit 1
    fi

    if [ -n "$VERSION_TYPE" ] && [ -n "$CUSTOM_VERSION" ]; then
        log_error "--type 和 --version 不能同时使用"
        show_help
        exit 1
    fi

    if [ -n "$VERSION_TYPE" ]; then
        case "$VERSION_TYPE" in
            major|minor|patch)
                ;;
            *)
                log_error "无效的版本类型: $VERSION_TYPE"
                log_error "支持的类型: major, minor, patch"
                exit 1
                ;;
        esac
    fi
}

# 主函数
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}       Git 发布脚本${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # 解析参数
    parse_arguments "$@"

    # 检查先决条件
    if ! check_prerequisites; then
        exit 1
    fi

    # 检查 Git 状态
    if ! check_git_status; then
        exit 1
    fi

    # 查找版本文件
    find_version_file

    # 获取当前版本
    if ! get_current_version; then
        exit 1
    fi

    # 计算新版本
    if ! calculate_new_version; then
        exit 1
    fi

    # 创建备份
    create_backup

    # 设置错误处理
    trap rollback ERR

    # 更新版本文件
    update_version_file

    # 生成 CHANGELOG
    if ! generate_changelog; then
        exit 1
    fi

    # 执行构建
    if ! run_build; then
        exit 1
    fi

    # 运行测试
    if ! run_tests; then
        exit 1
    fi

    # 提交更改
    commit_changes

    # 创建标签
    if ! create_tag; then
        exit 1
    fi

    # 推送到远程
    if ! push_to_remote; then
        exit 1
    fi

    # 清理备份
    rm -rf "$BACKUP_DIR"

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}       发布成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}版本: v${NEW_VERSION}${NC}"
    echo -e "${GREEN}分支: ${BRANCH_NAME}${NC}"
    echo -e "${GREEN}远程: ${REMOTE_NAME}${NC}"
    echo ""
}

# 执行主函数
main "$@"
