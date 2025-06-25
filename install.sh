#!/bin/bash

# Oh My Zsh 一键安装脚本
# 作者: AI Assistant
# 描述: 自动安装 oh-my-zsh, volta 以及相关插件和配置

set -e  # 遇到错误时退出

echo "🚀 开始安装 Oh My Zsh 环境..."

# 检查是否已安装zsh
if ! command -v zsh &> /dev/null; then
    echo "📦 安装 zsh..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y zsh
    elif command -v yum &> /dev/null; then
        sudo yum install -y zsh
    elif command -v pacman &> /dev/null; then
        sudo pacman -S zsh
    else
        echo "❌ 无法自动安装 zsh，请手动安装后重新运行此脚本"
        exit 1
    fi
fi

# 安装 Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "📦 安装 Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "✅ Oh My Zsh 已经安装"
fi

# 安装 Volta
if [ ! -d "$HOME/.volta" ]; then
    echo "📦 安装 Volta..."
    curl https://get.volta.sh | bash
    export VOLTA_HOME="$HOME/.volta"
    export PATH="$VOLTA_HOME/bin:$PATH"
else
    echo "✅ Volta 已经安装"
fi

# 安装 zsh-syntax-highlighting 插件
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    echo "📦 安装 zsh-syntax-highlighting 插件..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
else
    echo "✅ zsh-syntax-highlighting 插件已经安装"
fi

# 安装 zsh-autosuggestions 插件
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    echo "📦 安装 zsh-autosuggestions 插件..."
    git clone https://github.com/zsh-users/zsh-autosuggestions.git $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
else
    echo "✅ zsh-autosuggestions 插件已经安装"
fi

# 备份现有的 .zshrc 文件
if [ -f "$HOME/.zshrc" ]; then
    echo "📋 备份现有的 .zshrc 文件..."
    cp $HOME/.zshrc $HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
fi

# 创建新的 .zshrc 配置文件
echo "📝 创建新的 .zshrc 配置文件..."
cat > $HOME/.zshrc << 'EOF'
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="blinks"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

alias c='cursor'
EOF

# 设置 zsh 为默认 shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "🔧 设置 zsh 为默认 shell..."
    chsh -s $(which zsh)
fi

echo ""
echo "🎉 安装完成！"
echo ""
echo "📋 安装摘要："
echo "   ✅ Oh My Zsh"
echo "   ✅ Volta (Node.js 版本管理)"
echo "   ✅ zsh-syntax-highlighting 插件"
echo "   ✅ zsh-autosuggestions 插件"
echo "   ✅ blinks 主题"
echo "   ✅ cursor 别名"
echo ""
echo "🔄 请重新启动终端或运行以下命令来应用配置："
echo "   source ~/.zshrc"
echo ""
echo "💡 如果需要恢复之前的配置，可以使用备份文件："
echo "   ls ~/.zshrc.backup.*" 