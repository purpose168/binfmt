
git 发布脚本！以下是详细说明：

## 📋 脚本功能概览

[release.sh](file:///home/pps/code/binfmt/binfmt/release.sh) 是一个功能完整的发布脚本，包含以下特性：

### ✨ 核心功能

1. **版本号管理**
   - 支持 major/minor/patch 三种版本类型
   - 支持自定义版本号
   - 自动从文件或 Git 标签读取当前版本

2. **CHANGELOG 自动生成**
   - 从 Git 提交历史生成变更日志
   - 支持自定义发布说明
   - 自动更新 CHANGELOG.md 文件

3. **代码构建**
   - 执行 `docker buildx bake` 构建项目
   - 支持跳过构建步骤

4. **自动化测试**
   - 运行 `./hack/lint` 代码风格检查
   - 运行 `./hack/validate-vendor` 验证依赖
   - 运行 `./hack/install-and-test` 安装和测试
   - 支持跳过测试步骤

5. **Git 操作**
   - 提交版本更新和 CHANGELOG
   - 创建 Git 标签
   - 推送提交和标签到远程仓库

6. **错误处理与回滚**
   - 完善的错误检测机制
   - 失败时自动回滚已执行的操作
   - 删除已创建的标签
   - 回滚 Git 提交
   - 恢复备份的文件

### 🎯 使用方法

#### 基本用法

```bash
# 发布补丁版本（1.0.0 -> 1.0.1）
./release.sh --type patch

# 发布次版本（1.0.0 -> 1.1.0）
./release.sh --type minor

# 发布主版本（1.0.0 -> 2.0.0）
./release.sh --type major

# 使用自定义版本号
./release.sh --version 2.5.0

# 添加发布说明
./release.sh --type patch --notes "修复了几个bug\n优化了性能"

# 试运行模式（不实际执行）
./release.sh --type patch --dry-run

# 跳过构建和测试
./release.sh --type patch --skip-build --skip-test
```

#### 完整参数列表

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-t, --type <TYPE>` | 版本类型：major, minor, patch | 必需 |
| `-v, --version <VERSION>` | 自定义版本号（如 1.2.3） | - |
| `-n, --notes <NOTES>` | 发布说明（多行用 \n 分隔） | - |
| `-r, --remote <NAME>` | 远程仓库名称 | origin |
| `-b, --branch <NAME>` | 分支名称 | master |
| `--dry-run` | 试运行模式，不实际执行 | false |
| `--skip-build` | 跳过构建步骤 | false |
| `--skip-test` | 跳过测试步骤 | false |
| `--skip-changelog` | 跳过 CHANGELOG 生成 | false |
| `-h, --help` | 显示帮助信息 | - |

### 🔧 工作流程

脚本执行以下步骤：

1. **环境检查** - 验证必要工具（git, docker, jq）
2. **Git 状态检查** - 确保工作目录干净且与远程同步
3. **版本管理** - 读取当前版本并计算新版本
4. **创建备份** - 备份版本文件和 CHANGELOG
5. **更新文件** - 更新版本号和生成 CHANGELOG
6. **代码构建** - 执行 `docker buildx bake`
7. **运行测试** - 执行所有测试脚本
8. **提交更改** - 提交版本更新和 CHANGELOG
9. **创建标签** - 创建 Git 标签
10. **推送远程** - 推送提交和标签到远程仓库
11. **清理备份** - 删除临时备份文件

### 🛡️ 错误处理机制

脚本在任一环节失败时会自动回滚：

- ✅ 删除已创建的 Git 标签
- ✅ 回滚 Git 提交
- ✅ 恢复备份的版本文件
- ✅ 恢复备份的 CHANGELOG
- ✅ 清理临时文件

### 📝 示例场景

**场景 1：常规补丁发布**
```bash
./release.sh --type patch --notes "修复了内存泄漏问题"
```

**场景 2：重大版本更新**
```bash
./release.sh --type major --notes "完全重构架构，性能提升50%"
```

**场景 3：自定义版本发布**
```bash
./release.sh --version 3.0.0 --notes "发布 3.0 版本"
```

**场景 4：试运行验证**
```bash
./release.sh --type patch --dry-run
```

### 🎨 特色功能

- **彩色输出** - 使用颜色区分不同级别的日志信息
- **详细日志** - 每个步骤都有清晰的日志输出
- **灵活配置** - 支持跳过某些步骤以适应不同场景
- **安全可靠** - 完善的备份和回滚机制
- **用户友好** - 详细的帮助文档和错误提示

脚本已经设置为可执行，你可以直接使用！如果需要查看帮助信息，可以运行：

```bash
./release.sh --help
```


# 继续完成发布流程（推荐）
```bash
# 清理备份目录
rm -rf .release_backup/

# 添加并提交更改
git add VERSION CHANGELOG.md
git commit -m "Release v3.0.0

发布 3.0 版本"

# 创建标签
git tag -a v3.0.0 -m "Release version 3.0.0

发布 3.0 版本"

# 推送到远程
git push origin master
git push origin v3.0.0
```