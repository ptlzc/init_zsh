# Oh My Zsh 一键安装脚本

这是一个自动化安装脚本，用于快速配置 Oh My Zsh 开发环境。

## 🚀 功能特性

- 🔧 自动安装 zsh（如果未安装）
- 📦 安装 Oh My Zsh
- ⚡ 安装 Volta（Node.js 版本管理器）
- 🎨 配置 blinks 主题
- 🔌 安装实用插件：
  - `git` - Git 集成
  - `zsh-syntax-highlighting` - 语法高亮
  - `zsh-autosuggestions` - 自动建议
- 💻 设置 cursor 别名 (`c` 命令)
- 🔄 自动设置 zsh 为默认 shell

## 📋 安装要求

- Linux 系统（支持 apt-get, yum, 或 pacman）
- curl
- git
- 网络连接

## 🛠️ 使用方法

1. 克隆或下载此脚本：
   ```bash
   git clone <repository-url>
   cd init_zsh
   ```

2. 运行安装脚本：
   ```bash
   ./install.sh
   ```

3. 安装完成后，重启终端或执行：
   ```bash
   source ~/.zshrc
   ```

## 📁 安装内容

脚本将会：

1. **检查并安装 zsh**（如果未安装）
2. **安装 Oh My Zsh** 到 `~/.oh-my-zsh`
3. **安装 Volta** 到 `~/.volta`
4. **安装插件**：
   - `zsh-syntax-highlighting` → `~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting`
   - `zsh-autosuggestions` → `~/.oh-my-zsh/custom/plugins/zsh-autosuggestions`
5. **配置 .zshrc** 文件（会自动备份原文件）
6. **设置默认 shell** 为 zsh

## 🔧 配置详情

安装后的配置包括：

- **主题**: blinks
- **插件**: git, zsh-syntax-highlighting, zsh-autosuggestions
- **环境变量**: Volta 路径配置
- **别名**: `c='cursor'`

## 🛡️ 安全特性

- ✅ 自动备份现有的 `.zshrc` 文件
- ✅ 检查是否已安装组件，避免重复安装
- ✅ 错误处理，遇到问题时自动停止

## 🔄 恢复配置

如果需要恢复原来的配置，可以使用自动生成的备份文件：

```bash
# 查看备份文件
ls ~/.zshrc.backup.*

# 恢复备份（替换为实际的备份文件名）
cp ~/.zshrc.backup.20231201_123456 ~/.zshrc
```

## 🎯 使用建议

安装完成后，您可以：

1. 使用 `c` 命令快速启动 Cursor
2. 享受语法高亮和自动建议功能
3. 使用 Volta 管理 Node.js 版本
4. 利用 Oh My Zsh 的丰富功能

## ❓ 故障排除

如果遇到问题：

1. 确保有网络连接
2. 检查是否有必要的权限
3. 手动安装缺失的依赖（curl, git）
4. 查看错误信息并根据提示操作

## 📞 支持

如有问题，请检查：
- 终端输出的错误信息
- 系统是否支持当前的包管理器
- 网络连接是否正常 