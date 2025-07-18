#!/bin/bash

# Oh My Zsh 完整开发环境交互式安装脚本
# 作者: AI Assistant
# 版本: 2.0
# 描述: 交互式安装和配置完整的开发环境，包括：
#       - 系统检测和源配置
#       - 代理设置功能
#       - 主机名配置
#       - Git 工具及配置
#       - Oh My Zsh 及插件
#       - Volta (Node.js 版本管理)
#       - Miniconda (Python 环境管理)
#       - 实用别名和配置

set -e  # 遇到错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "脚本在第 $line_number 行发生错误，退出码: $exit_code"
    log_warning "如果需要帮助，请检查错误信息或手动执行相关步骤"
    exit $exit_code
}

# 设置错误处理
trap 'handle_error $LINENO' ERR

# 全局变量
BACKUP_DIR=""
PACKAGE_MANAGER=""
OFFLINE_MODE=false
CURRENT_HOSTNAME=""
IS_CHINA=false
SYSTEM_INFO=""
DISTRO=""
VERSION=""

# 系统检测函数
detect_system() {
    log_info "检测系统信息..."
    
    # 检测发行版
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        SYSTEM_INFO="$PRETTY_NAME"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        VERSION=$(cat /etc/debian_version)
        SYSTEM_INFO="Debian $VERSION"
    else
        DISTRO="unknown"
        VERSION="unknown"
        SYSTEM_INFO="Unknown Linux"
    fi
    
    log_success "系统信息: $SYSTEM_INFO"
    log_info "发行版: $DISTRO, 版本: $VERSION"
}

# 检测地理位置
detect_location() {
    log_info "检测地理位置..."
    
    # 尝试通过多个服务检测IP位置
    local country=""
    
    # 方法1: ipinfo.io
    if [ "$OFFLINE_MODE" = false ]; then
        country=$(curl -s --connect-timeout 5 ipinfo.io/country 2>/dev/null || echo "")
    fi
    
    # 方法2: 如果第一个失败，尝试 ip-api.com
    if [ -z "$country" ] && [ "$OFFLINE_MODE" = false ]; then
        country=$(curl -s --connect-timeout 5 "http://ip-api.com/line?fields=countryCode" 2>/dev/null || echo "")
    fi
    
    # 方法3: 检测时区
    if [ -z "$country" ]; then
        local timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")
        if [[ "$timezone" =~ ^Asia/(Shanghai|Chongqing|Harbin|Kashgar|Urumqi)$ ]]; then
            country="CN"
        fi
    fi
    
    if [ "$country" = "CN" ]; then
        IS_CHINA=true
        log_success "检测到位于中国，将使用国内镜像源"
    else
        IS_CHINA=false
        log_info "检测到位于海外，将使用官方源"
    fi
}

# 配置APT源
configure_apt_sources() {
    if [ "$DISTRO" != "ubuntu" ] && [ "$DISTRO" != "debian" ]; then
        return 0
    fi
    
    log_info "配置软件源..."
    
    # 备份原始sources.list
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)
    
    if [ "$IS_CHINA" = true ]; then
        log_info "配置清华大学镜像源..."
        
        if [ "$DISTRO" = "ubuntu" ]; then
            # Ubuntu 清华源
            sudo tee /etc/apt/sources.list > /dev/null <<EOF
# 清华大学 Ubuntu 镜像源
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
EOF
        elif [ "$DISTRO" = "debian" ]; then
            # Debian 清华源
            local debian_codename=$(lsb_release -cs 2>/dev/null || echo "bullseye")
            sudo tee /etc/apt/sources.list > /dev/null <<EOF
# 清华大学 Debian 镜像源
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $debian_codename main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $debian_codename-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security $debian_codename-security main contrib non-free
EOF
        fi
        
        log_success "已配置清华大学镜像源"
    else
        log_info "使用官方软件源"
    fi
}

# 代理设置函数
setup_proxy_functions() {
    log_info "设置代理功能..."
    
    # 创建代理配置脚本
    cat > "$HOME/.proxy_config" << 'EOF'
#!/bin/bash

# 代理配置
HTTP_PROXY="http://192.168.10.100:2081"
SOCKS_PROXY="socks5://192.168.10.100:2080"

# 开启代理
proxy_on() {
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTP_PROXY"
    export HTTP_PROXY="$HTTP_PROXY"
    export HTTPS_PROXY="$HTTP_PROXY"
    export socks_proxy="$SOCKS_PROXY"
    export SOCKS_PROXY="$SOCKS_PROXY"
    export no_proxy="localhost,127.0.0.1,::1"
    export NO_PROXY="localhost,127.0.0.1,::1"
    
    # Git 代理
    git config --global http.proxy "$HTTP_PROXY"
    git config --global https.proxy "$HTTP_PROXY"
    
    # npm 代理
    if command -v npm &> /dev/null; then
        npm config set proxy "$HTTP_PROXY"
        npm config set https-proxy "$HTTP_PROXY"
    fi
    
    echo "✅ 代理已开启"
    echo "   HTTP/HTTPS: $HTTP_PROXY"
    echo "   SOCKS5: $SOCKS_PROXY"
}

# 关闭代理
proxy_off() {
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    unset socks_proxy SOCKS_PROXY no_proxy NO_PROXY
    
    # Git 代理
    git config --global --unset http.proxy 2>/dev/null || true
    git config --global --unset https.proxy 2>/dev/null || true
    
    # npm 代理
    if command -v npm &> /dev/null; then
        npm config delete proxy 2>/dev/null || true
        npm config delete https-proxy 2>/dev/null || true
    fi
    
    echo "✅ 代理已关闭"
}

# 检查代理状态
proxy_status() {
    echo "🔍 代理状态检查:"
    echo "   HTTP_PROXY: ${HTTP_PROXY:-未设置}"
    echo "   HTTPS_PROXY: ${HTTPS_PROXY:-未设置}"
    echo "   SOCKS_PROXY: ${SOCKS_PROXY:-未设置}"
    echo "   Git HTTP 代理: $(git config --global http.proxy 2>/dev/null || echo '未设置')"
    echo "   Git HTTPS 代理: $(git config --global https.proxy 2>/dev/null || echo '未设置')"
    if command -v npm &> /dev/null; then
        echo "   NPM 代理: $(npm config get proxy 2>/dev/null || echo '未设置')"
    fi
}
EOF

    chmod +x "$HOME/.proxy_config"
    log_success "代理配置已创建: $HOME/.proxy_config"
}

# NPM/PNPM 源配置
setup_npm_sources() {
    log_info "配置 NPM/PNPM 源切换功能..."
    
    cat > "$HOME/.npm_sources" << 'EOF'
#!/bin/bash

# NPM/PNPM 源配置

# 切换到淘宝源
npm_taobao() {
    if command -v npm &> /dev/null; then
        npm config set registry https://registry.npmmirror.com/
        echo "✅ NPM 已切换到淘宝源"
    fi
    
    if command -v pnpm &> /dev/null; then
        pnpm config set registry https://registry.npmmirror.com/
        echo "✅ PNPM 已切换到淘宝源"
    fi
}

# 切换到官方源
npm_official() {
    if command -v npm &> /dev/null; then
        npm config set registry https://registry.npmjs.org/
        echo "✅ NPM 已切换到官方源"
    fi
    
    if command -v pnpm &> /dev/null; then
        pnpm config set registry https://registry.npmjs.org/
        echo "✅ PNPM 已切换到官方源"
    fi
}

# 查看当前源
npm_current() {
    echo "🔍 当前源配置:"
    if command -v npm &> /dev/null; then
        echo "   NPM: $(npm config get registry)"
    else
        echo "   NPM: 未安装"
    fi
    
    if command -v pnpm &> /dev/null; then
        echo "   PNPM: $(pnpm config get registry)"
    else
        echo "   PNPM: 未安装"
    fi
}
EOF

    chmod +x "$HOME/.npm_sources"
    log_success "NPM源配置已创建: $HOME/.npm_sources"
}

# 检测包管理器
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt-get"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# 检查网络连接
check_network() {
    if ping -c 1 8.8.8.8 &> /dev/null; then
        return 0
    elif ping -c 1 114.114.114.114 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 创建备份目录
# 初始化函数
initialize() {
    # 创建备份目录
    BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    log_info "创建备份目录: $BACKUP_DIR"

    # 备份现有配置文件
    backup_config() {
        local file="$1"
        local backup_name="$2"
        
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/$backup_name"
            log_success "已备份 $file 到 $BACKUP_DIR/$backup_name"
        fi
    }

    # 备份重要配置文件
    log_info "备份现有配置文件..."
    backup_config "$HOME/.zshrc" "zshrc"
    backup_config "$HOME/.bashrc" "bashrc"
    backup_config "$HOME/.profile" "profile"
    backup_config "$HOME/.gitconfig" "gitconfig"

    # 系统检测
    detect_system
    
    # 检测包管理器
    PACKAGE_MANAGER=$(detect_package_manager)
    log_info "检测到包管理器: $PACKAGE_MANAGER"

    if [ "$PACKAGE_MANAGER" = "unknown" ]; then
        log_error "无法检测到支持的包管理器 (apt-get, yum, pacman)"
        log_warning "请手动安装所需的包，然后重新运行此脚本"
        exit 1
    fi

    # 检查网络连接
    if check_network; then
        log_success "网络连接正常"
        OFFLINE_MODE=false
        # 检测地理位置
        detect_location
    else
        log_warning "网络连接不可用，某些功能可能受限"
        OFFLINE_MODE=true
        IS_CHINA=false
    fi

    # 获取当前主机名
    CURRENT_HOSTNAME=$(hostname)
    log_info "当前主机名: $CURRENT_HOSTNAME"
}

# 显示主菜单
show_menu() {
    clear
    echo "=============================================="
    echo "   Oh My Zsh 完整开发环境交互式安装脚本"
    echo "=============================================="
    echo ""
    echo "🖥️  系统信息: $SYSTEM_INFO"
    echo "🌍 地理位置: $([ "$IS_CHINA" = true ] && echo "中国" || echo "海外")"
    echo "📦 包管理器: $PACKAGE_MANAGER"
    echo "🌐 网络状态: $([ "$OFFLINE_MODE" = false ] && echo "在线" || echo "离线")"
    echo "🏠 主机名: $CURRENT_HOSTNAME"
    echo ""
    echo "=============================================="
    echo "请选择要执行的操作："
    echo ""
    echo "1️⃣  配置系统源和代理功能"
    echo "2️⃣  设置主机名"
    echo "3️⃣  安装基础开发工具"
    echo "4️⃣  安装和配置 Git"
    echo "5️⃣  安装 Oh My Zsh 和插件"
    echo "6️⃣  安装 Volta 和 Node.js 工具"
    echo "7️⃣  安装 Miniconda"
    echo "8️⃣  安装 Docker"
    echo "9️⃣  生成配置文件和验证安装"
    echo "🔟  硬盘扩容功能"
    echo ""
    echo "🚀 all  - 执行全部安装"
    echo "🔧 menu - 显示此菜单"
    echo "❌ q    - 退出脚本"
    echo ""
    echo "=============================================="
}

# 1. 配置系统源和代理功能
option_1_sources_proxy() {
    log_info "========== 配置系统源和代理功能 =========="
    
    # 配置软件源
    configure_apt_sources
    
    # 设置代理功能
    setup_proxy_functions
    
    # 设置NPM源功能
    setup_npm_sources
    
    log_success "系统源和代理功能配置完成"
    echo ""
    echo "💡 使用说明："
    echo "   - 代理控制: source ~/.proxy_config && proxy_on/proxy_off/proxy_status"
    echo "   - NPM源切换: source ~/.npm_sources && npm_taobao/npm_official/npm_current"
    echo ""
    read -p "按回车键继续..." -r
}

# 2. 设置主机名
option_2_hostname() {
    log_info "========== 设置主机名 =========="
    
    echo "🏠 当前主机名: $CURRENT_HOSTNAME"
    echo "是否需要重设主机名？ (y/n)"
    read -r reset_hostname
    
    if [[ "$reset_hostname" =~ ^[Yy]$ ]]; then
        echo "📝 请输入新的主机名："
        read -r new_hostname
        if [ -n "$new_hostname" ]; then
            log_info "设置主机名为: $new_hostname"
            sudo hostnamectl set-hostname "$new_hostname"
            CURRENT_HOSTNAME="$new_hostname"
            log_success "主机名已设置为: $new_hostname"
        else
            log_warning "主机名不能为空，跳过设置"
        fi
    else
        log_info "保持当前主机名: $CURRENT_HOSTNAME"
    fi
    
    echo ""
    read -p "按回车键继续..." -r
}

# 3. 安装基础开发工具
option_3_dev_tools() {
    log_info "========== 安装基础开发工具 =========="
    
    # 检查sudo权限
    if ! sudo -n true 2>/dev/null; then
        log_info "此操作需要sudo权限"
        sudo -v || return 1
    fi
    
    # 更新软件包列表
    case $PACKAGE_MANAGER in
        "apt-get")
            log_info "更新软件包列表..."
            sudo apt-get update
            
            log_info "安装基础开发工具..."
            sudo apt-get install -y \
                curl wget vim nano tree htop unzip zip \
                build-essential software-properties-common \
                apt-transport-https ca-certificates gnupg lsb-release \
                git-core openssh-client openssh-server \
                net-tools dnsutils iputils-ping \
                jq tmux screen \
                python3 python3-pip python3-venv \
                nodejs npm \
                default-jdk maven gradle
            ;;
        "yum")
            log_info "更新软件包列表..."
            sudo yum update -y
            
            log_info "安装基础开发工具..."
            sudo yum install -y \
                curl wget vim nano tree htop unzip zip \
                gcc gcc-c++ make epel-release \
                git openssh-clients openssh-server \
                net-tools bind-utils iputils \
                jq tmux screen \
                python3 python3-pip python3-venv \
                nodejs npm \
                java-11-openjdk-devel maven
            ;;
        "pacman")
            log_info "更新软件包列表..."
            sudo pacman -Syu --noconfirm
            
            log_info "安装基础开发工具..."
            sudo pacman -S --noconfirm \
                curl wget vim nano tree htop unzip zip \
                base-devel \
                git openssh \
                net-tools dnsutils iputils \
                jq tmux screen \
                python python-pip python-virtualenv \
                nodejs npm \
                jdk11-openjdk maven gradle
            ;;
    esac
    
    log_success "基础开发工具安装完成"
    
    # 验证安装
    log_info "验证已安装的工具..."
    local tools=("curl" "wget" "vim" "nano" "tree" "htop" "git" "python3" "node" "npm" "java")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "$tool: $(command -v $tool)"
        else
            log_warning "$tool: 未找到"
        fi
    done
    
    echo ""
    read -p "按回车键继续..." -r
}

# 4. 安装和配置 Git
option_4_git() {
    log_info "========== 安装和配置 Git =========="
    
    # 安装 Git
    if ! command -v git &> /dev/null; then
        log_info "安装 Git..."
        case $PACKAGE_MANAGER in
            "apt-get")
                sudo apt-get install -y git
                ;;
            "yum")
                sudo yum install -y git
                ;;
            "pacman")
                sudo pacman -S --noconfirm git
                ;;
        esac
    else
        log_success "Git 已经安装"
    fi
    
    # 配置 Git 用户信息
    log_info "配置 Git 用户信息..."
    git config --global user.name "$CURRENT_HOSTNAME"
    git config --global user.email "$CURRENT_HOSTNAME@localhost"
    log_success "Git 用户名设置为: $CURRENT_HOSTNAME"
    log_success "Git 邮箱设置为: $CURRENT_HOSTNAME@localhost"
    
    echo ""
    read -p "按回车键继续..." -r
}

# 5. 安装 Oh My Zsh 和插件
option_5_ohmyzsh() {
    log_info "========== 安装 Oh My Zsh 和插件 =========="
    
    # 安装 zsh
    if ! command -v zsh &> /dev/null; then
        log_info "安装 zsh..."
        case $PACKAGE_MANAGER in
            "apt-get")
                sudo apt-get install -y zsh
                ;;
            "yum")
                sudo yum install -y zsh
                ;;
            "pacman")
                sudo pacman -S --noconfirm zsh
                ;;
        esac
    else
        log_success "zsh 已经安装"
    fi
    
    # 安装 Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        if [ "$OFFLINE_MODE" = false ]; then
            log_info "安装 Oh My Zsh..."
            if ! sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
                log_error "Oh My Zsh 自动安装失败"
                return 1
            fi
        else
            log_warning "离线模式下无法安装 Oh My Zsh"
            return 1
        fi
    else
        log_success "Oh My Zsh 已经安装"
    fi
    
    # 安装插件
    if [ "$OFFLINE_MODE" = false ]; then
        # 根据地理位置选择GitHub镜像
        local github_base_url="https://github.com"
        if [ "$IS_CHINA" = true ]; then
            github_base_url="https://gitee.com/mirrors"
            log_info "使用 Gitee 镜像加速 GitHub 仓库克隆..."
        fi
        
        # zsh-syntax-highlighting
        if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
            log_info "安装 zsh-syntax-highlighting 插件..."
            if [ "$IS_CHINA" = true ]; then
                # 尝试 Gitee 镜像
                if ! git clone https://gitee.com/mirrors/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null; then
                    log_warning "Gitee 镜像失败，尝试 GitHub 原站..."
                    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
                fi
            else
                git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
            fi
        else
            log_success "zsh-syntax-highlighting 插件已安装"
        fi
        
        # zsh-autosuggestions
        if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
            log_info "安装 zsh-autosuggestions 插件..."
            if [ "$IS_CHINA" = true ]; then
                # 尝试 Gitee 镜像
                if ! git clone https://gitee.com/mirrors/zsh-autosuggestions.git $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null; then
                    log_warning "Gitee 镜像失败，尝试 GitHub 原站..."
                    git clone https://github.com/zsh-users/zsh-autosuggestions.git $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
                fi
            else
                git clone https://github.com/zsh-users/zsh-autosuggestions.git $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
            fi
        else
            log_success "zsh-autosuggestions 插件已安装"
        fi
    fi
    
    log_success "Oh My Zsh 和插件安装完成"
    echo ""
    read -p "按回车键继续..." -r
}

# 6. 安装 Volta 和 Node.js 工具
option_6_volta() {
    log_info "========== 安装 Volta 和 Node.js 工具 =========="
    
    # 安装 Volta
    if [ ! -d "$HOME/.volta" ]; then
        if [ "$OFFLINE_MODE" = false ]; then
            log_info "安装 Volta..."
            if curl https://get.volta.sh | bash; then
                export VOLTA_HOME="$HOME/.volta"
                export PATH="$VOLTA_HOME/bin:$PATH"
                log_success "Volta 已安装"
            else
                log_error "Volta 安装失败"
                return 1
            fi
        else
            log_warning "离线模式下无法安装 Volta"
            return 1
        fi
    else
        log_success "Volta 已经安装"
        export VOLTA_HOME="$HOME/.volta"
        export PATH="$VOLTA_HOME/bin:$PATH"
    fi
    
    # 安装 Node.js
    if command -v volta &> /dev/null; then
        log_info "通过 Volta 安装 Node.js LTS..."
        volta install node
        
        log_info "安装 PNPM..."
        volta install pnpm
        
        # 设置 PNPM home
        if command -v pnpm &> /dev/null; then
            mkdir -p "$HOME/.pnpm"
            pnpm config set store-dir "$HOME/.pnpm/store"
            pnpm config set global-dir "$HOME/.pnpm/global"
            pnpm config set cache-dir "$HOME/.pnpm/cache"
            log_success "PNPM 配置完成"
        fi
        
        # 根据地理位置设置默认源
        if [ "$IS_CHINA" = true ]; then
            log_info "设置淘宝源..."
            source "$HOME/.npm_sources" && npm_taobao
        else
            log_info "使用官方源..."
            source "$HOME/.npm_sources" && npm_official
        fi
        
        log_success "Node.js 工具安装完成"
    fi
    
    echo ""
    read -p "按回车键继续..." -r
}

# 7. 安装 Miniconda
option_7_conda() {
    log_info "========== 安装 Miniconda =========="
    
    if [ ! -d "$HOME/miniconda3" ] && [ ! -d "$HOME/anaconda3" ]; then
        if [ "$OFFLINE_MODE" = false ]; then
            log_info "下载并安装 Miniconda..."
            if wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh; then
                bash /tmp/miniconda.sh -b -p $HOME/miniconda3
                rm /tmp/miniconda.sh
                export PATH="$HOME/miniconda3/bin:$PATH"
                $HOME/miniconda3/bin/conda init zsh
                
                # 配置中国镜像源
                if [ "$IS_CHINA" = true ]; then
                    log_info "配置清华大学 Conda 镜像源..."
                    $HOME/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
                    $HOME/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
                    $HOME/miniconda3/bin/conda config --set show_channel_urls yes
                fi
                
                log_success "Miniconda 已安装"
            else
                log_error "Miniconda 下载失败"
                return 1
            fi
        else
            log_warning "离线模式下无法安装 Miniconda"
            return 1
        fi
    else
        log_success "Conda 已经安装"
    fi
    
    echo ""
    read -p "按回车键继续..." -r
}

# 8. 安装 Docker
option_8_docker() {
    log_info "========== 安装 Docker =========="
    
    echo "是否安装 Docker？ (y/n)"
    read -r install_docker
    
    if [[ "$install_docker" =~ ^[Yy]$ ]]; then
        if [ "$OFFLINE_MODE" = false ]; then
            log_info "安装 Docker..."
            case $PACKAGE_MANAGER in
                "apt-get")
                    # 根据系统类型和地理位置选择合适的源
                    if [ "$IS_CHINA" = true ]; then
                        log_info "使用清华大学 Docker 镜像源..."
                        # 添加清华大学 Docker 源
                        sudo mkdir -p /etc/apt/keyrings
                        curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/$DISTRO/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/$DISTRO $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                    else
                        log_info "使用官方 Docker 源..."
                        # 使用官方源
                        sudo mkdir -p /etc/apt/keyrings
                        curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                    fi
                    
                    # 更新并安装 Docker
                    sudo apt-get update
                    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                    
                    # 启动 Docker 服务
                    sudo systemctl start docker
                    sudo systemctl enable docker
                    
                    # 添加用户到 docker 组
                    sudo groupadd docker 2>/dev/null || true
                    sudo usermod -aG docker $USER
                    
                    # 配置 Docker 镜像源（中国用户）
                    if [ "$IS_CHINA" = true ]; then
                        log_info "配置 Docker 镜像加速器..."
                        sudo mkdir -p /etc/docker
                        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com",
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn"
    ],
    "ipv6": false,
    "fixed-cidr-v6": false
}
EOF
                        sudo systemctl restart docker
                        log_success "Docker 镜像加速器已配置"
                    fi
                    ;;
                "yum")
                    if [ "$IS_CHINA" = true ]; then
                        log_info "使用清华大学 Docker 镜像源..."
                        sudo yum install -y yum-utils
                        sudo yum-config-manager --add-repo https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/docker-ce.repo
                    else
                        log_info "使用官方 Docker 源..."
                        sudo yum install -y yum-utils
                        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                    fi
                    
                    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                    sudo systemctl start docker
                    sudo systemctl enable docker
                    sudo usermod -aG docker $USER
                    
                    # 配置 Docker 镜像源（中国用户）
                    if [ "$IS_CHINA" = true ]; then
                        log_info "配置 Docker 镜像加速器..."
                        sudo mkdir -p /etc/docker
                        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com",
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn"
    ],
    "ipv6": false,
    "fixed-cidr-v6": false
}
EOF
                        sudo systemctl restart docker
                        log_success "Docker 镜像加速器已配置"
                    fi
                    ;;
                "pacman")
                    sudo pacman -S --noconfirm docker docker-compose
                    sudo systemctl start docker
                    sudo systemctl enable docker
                    sudo usermod -aG docker $USER
                    
                    # 配置 Docker 镜像源（中国用户）
                    if [ "$IS_CHINA" = true ]; then
                        log_info "配置 Docker 镜像加速器..."
                        sudo mkdir -p /etc/docker
                        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com",
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn"
    ],
    "ipv6": false,
    "fixed-cidr-v6": false
}
EOF
                        sudo systemctl restart docker
                        log_success "Docker 镜像加速器已配置"
                    fi
                    ;;
            esac
            
            log_success "Docker 已安装"
            log_info "注意：请注销并重新登录以使用 Docker 命令，或运行 'newgrp docker'"
        else
            log_warning "离线模式下无法安装 Docker"
        fi
    else
        log_info "跳过 Docker 安装"
    fi
    
    echo ""
    read -p "按回车键继续..." -r
}

# 9. 生成配置文件和验证安装
option_9_config() {
    log_info "========== 生成配置文件和验证安装 =========="
    
    # 备份现有的 .zshrc 文件
    if [ -f "$HOME/.zshrc" ]; then
        log_info "备份现有的 .zshrc 文件..."
        cp $HOME/.zshrc $HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # 生成新的 .zshrc 配置文件
    generate_zshrc
    
    # 设置 zsh 为默认 shell
    if [ "$SHELL" != "$(which zsh)" ]; then
        log_info "设置 zsh 为默认 shell..."
        chsh -s $(which zsh)
    fi
    
    # 生成安装报告
    generate_install_report
    
    # 验证安装
    verify_installation
    
    log_success "配置文件生成和验证完成"
    echo ""
    read -p "按回车键继续..." -r
}

# 生成 .zshrc 配置文件
generate_zshrc() {
    log_info "创建新的 .zshrc 配置文件..."
    
cat > $HOME/.zshrc << 'EOF'
# Oh My Zsh 配置文件
export ZSH="$HOME/.oh-my-zsh"

# 主题设置
ZSH_THEME="blinks"

# 插件配置
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# Volta 配置
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# PNPM 配置
export PNPM_HOME="$HOME/.pnpm"
export PATH="$PNPM_HOME:$PATH"

# 代理功能
source ~/.proxy_config 2>/dev/null || true

# NPM 源切换功能
source ~/.npm_sources 2>/dev/null || true

# Conda 初始化
__conda_setup="$('$HOME/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup

# 别名设置
alias c='cursor'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# 自定义函数
alias proxy-on='proxy_on'
alias proxy-off='proxy_off'
alias proxy-status='proxy_status'
alias npm-taobao='npm_taobao'
alias npm-official='npm_official'
alias npm-current='npm_current'

# 欢迎信息
echo "🎉 Welcome to your enhanced development environment!"
echo "💡 Useful commands:"
echo "   proxy-on/off/status - 代理控制"
echo "   npm-taobao/official/current - NPM源切换"
echo "   c - 启动 Cursor"
EOF

    log_success ".zshrc 配置文件已创建"
}

# 生成安装报告
generate_install_report() {
    local report_file="$HOME/zsh_install_report_$(date +%Y%m%d_%H%M%S).txt"
    log_info "生成安装报告..."

cat > "$report_file" << EOF
===========================================
Oh My Zsh 完整开发环境安装报告
===========================================
安装时间: $(date)
主机名: $CURRENT_HOSTNAME
系统信息: $SYSTEM_INFO
发行版: $DISTRO $VERSION
包管理器: $PACKAGE_MANAGER
地理位置: $([ "$IS_CHINA" = true ] && echo "中国" || echo "海外")
离线模式: $OFFLINE_MODE

===========================================
已安装的工具和配置
===========================================
✅ 系统包管理器: $PACKAGE_MANAGER
✅ 基础开发工具: $(dpkg -l | grep -E "(curl|wget|vim|tree)" | wc -l) 个包已安装
✅ Git: $(git --version 2>/dev/null || echo "未安装")
✅ Zsh: $(zsh --version 2>/dev/null || echo "未安装")
✅ Oh My Zsh: $([ -d "$HOME/.oh-my-zsh" ] && echo "已安装" || echo "未安装")
✅ Volta: $([ -d "$HOME/.volta" ] && echo "已安装" || echo "未安装")
✅ Node.js: $(node --version 2>/dev/null || echo "未安装")
✅ NPM: $(npm --version 2>/dev/null || echo "未安装")
✅ PNPM: $(pnpm --version 2>/dev/null || echo "未安装")
✅ Miniconda: $([ -d "$HOME/miniconda3" ] && echo "已安装" || echo "未安装")
✅ Docker: $(docker --version 2>/dev/null || echo "未安装")

===========================================
配置信息
===========================================
Git 用户名: $(git config --global user.name)
Git 邮箱: $(git config --global user.email)
NPM 源: $(npm config get registry 2>/dev/null || echo "未配置")
PNPM 源: $(pnpm config get registry 2>/dev/null || echo "未配置")

===========================================
备份文件位置
===========================================
$BACKUP_DIR

===========================================
使用指南
===========================================
1. 重新启动终端或运行: source ~/.zshrc
2. 代理控制: proxy-on, proxy-off, proxy-status
3. NPM源切换: npm-taobao, npm-official, npm-current
4. 使用 volta install node@18 安装特定版本 Node.js
5. 使用 conda create -n myenv python=3.9 创建 Python 环境
6. 使用 c 命令启动 Cursor 编辑器
EOF

    log_success "安装报告已保存到: $report_file"
}

# 验证安装
verify_installation() {
    log_info "验证安装结果..."
    local verification_passed=true

    # 检查关键组件
    local checks=(
        "zsh:$(command -v zsh &> /dev/null && echo "✅" || echo "❌")"
        "git:$(command -v git &> /dev/null && echo "✅" || echo "❌")"
        "oh-my-zsh:$([ -d "$HOME/.oh-my-zsh" ] && echo "✅" || echo "❌")"
        "volta:$([ -d "$HOME/.volta" ] && echo "✅" || echo "❌")"
        "node:$(command -v node &> /dev/null && echo "✅" || echo "❌")"
        "conda:$([ -d "$HOME/miniconda3" ] && echo "✅" || echo "❌")"
    )

    echo "📋 安装验证结果:"
    for check in "${checks[@]}"; do
        local name=$(echo "$check" | cut -d: -f1)
        local status=$(echo "$check" | cut -d: -f2)
        echo "   $name: $status"
        if [ "$status" = "❌" ]; then
            verification_passed=false
        fi
    done

    if [ "$verification_passed" = true ]; then
        log_success "所有关键组件验证通过！"
    else
        log_warning "某些组件安装可能有问题，请检查上面的结果"
    fi
}

# 执行所有安装步骤
install_all() {
    log_info "========== 执行完整安装 =========="
    
    option_1_sources_proxy
    option_2_hostname
    option_3_dev_tools
    option_4_git
    option_5_ohmyzsh
    option_6_volta
    option_7_conda
    option_8_docker
    option_9_config
    
    echo ""
    echo "🎉 完整安装已完成！"
    echo "🔄 请重新启动终端或运行 'source ~/.zshrc' 来应用所有配置"
    echo ""
}

# 10. 硬盘扩容功能
option_10_disk_expand() {
    log_info "========== 硬盘扩容功能 =========="
    
    # 检查是否有sudo权限
    if ! sudo -n true 2>/dev/null; then
        log_info "此操作需要sudo权限"
        sudo -v || return 1
    fi
    
    # 检测可扩容的硬盘
    detect_expandable_disks
    
    echo ""
    read -p "按回车键继续..." -r
}

# 检测可扩容的硬盘
detect_expandable_disks() {
    log_info "检测可扩容的硬盘..."
    
    # 获取所有磁盘信息
    local -a disks
    local -a disk_info
    
    # 使用lsblk获取磁盘信息
    while IFS= read -r line; do
        # 匹配磁盘行 (TYPE=disk)
        if echo "$line" | grep -q " disk "; then
            local disk_name=$(echo "$line" | awk '{print $1}')
            local disk_size=$(echo "$line" | awk '{print $4}')
            
            # 检查磁盘名称格式
            if [[ "$disk_name" =~ ^(sd[a-z]|vd[a-z]|nvme[0-9]n[0-9]|xvd[a-z]|hd[a-z])$ ]]; then
                # 检查是否有LVM分区
                if lsblk -no TYPE,FSTYPE /dev/$disk_name 2>/dev/null | grep -q "lvm"; then
                    disks+=("$disk_name")
                    disk_info+=("$disk_name:$disk_size")
                    log_info "发现可扩容磁盘: /dev/$disk_name ($disk_size)"
                fi
            fi
        fi
    done < <(lsblk -no NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS 2>/dev/null)
    
    if [ ${#disks[@]} -eq 0 ]; then
        log_warning "未发现可扩容的LVM磁盘"
        return 1
    fi
    
    # 如果只有一个磁盘，直接扩容
    if [ ${#disks[@]} -eq 1 ]; then
        local selected_disk="${disks[0]}"
        log_info "发现唯一可扩容磁盘: /dev/$selected_disk"
        expand_disk "$selected_disk"
    else
        # 多个磁盘，让用户选择
        log_info "发现多个可扩容磁盘，请选择："
        echo ""
        
        local i=1
        for disk_item in "${disk_info[@]}"; do
            local disk_name="${disk_item%%:*}"
            local disk_size="${disk_item##*:}"
            echo "$i) /dev/$disk_name ($disk_size)"
            ((i++))
        done
        
        echo ""
        echo -n "请选择要扩容的磁盘 (1-${#disks[@]}): "
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#disks[@]} ]; then
            local selected_disk="${disks[$((choice-1))]}"
            log_info "选择扩容磁盘: /dev/$selected_disk"
            expand_disk "$selected_disk"
        else
            log_error "无效选择"
            return 1
        fi
    fi
}

# 扩容磁盘
expand_disk() {
    local disk_name="$1"
    local disk_path="/dev/$disk_name"
    
    log_info "开始扩容磁盘: $disk_path"
    
    # 显示当前磁盘使用情况
    log_info "当前磁盘使用情况:"
    df -h | grep -E "(Filesystem|/dev/mapper|/dev/$disk_name)"
    echo ""
    
    # 检查磁盘分区类型
    local partition_table=$(parted -s "$disk_path" print 2>/dev/null | grep "Partition Table:" | awk '{print $3}')
    log_info "分区表类型: $partition_table"
    
    # 获取磁盘信息
    log_info "磁盘分区信息:"
    parted -s "$disk_path" print 2>/dev/null
    echo ""
    
    # 检查是否有LVM物理卷
    local pv_info=$(pvs 2>/dev/null | grep "$disk_name")
    if [ -z "$pv_info" ]; then
        log_error "未发现LVM物理卷"
        return 1
    fi
    
    log_info "LVM物理卷信息:"
    echo "$pv_info"
    echo ""
    
    # 确认扩容
    echo "⚠️  注意：扩容操作将修改磁盘分区，请确保已备份重要数据"
    echo "是否继续扩容？ (y/n)"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "取消扩容操作"
        return 0
    fi
    
    # 开始扩容过程
    log_info "开始扩容过程..."
    
    # 1. 查找需要扩展的分区
    local lvm_partition=$(lsblk -no NAME,TYPE "$disk_path" 2>/dev/null | grep part | tail -1 | awk '{print $1}')
    if [ -z "$lvm_partition" ]; then
        log_error "未找到LVM分区"
        return 1
    fi
    
    local partition_path="/dev/$lvm_partition"
    log_info "LVM分区: $partition_path"
    
    # 2. 获取分区号
    local partition_number=$(echo "$lvm_partition" | sed "s/$disk_name//")
    log_info "分区号: $partition_number"
    
    # 3. 使用parted扩展分区
    log_info "扩展分区 $partition_number ..."
    
    # 检查是否是扩展分区内的逻辑分区
    if parted -s "$disk_path" print 2>/dev/null | grep -q "extended"; then
        # 有扩展分区，需要先扩展扩展分区，再扩展逻辑分区
        local extended_partition=$(parted -s "$disk_path" print 2>/dev/null | grep "extended" | awk '{print $1}')
        log_info "扩展扩展分区 $extended_partition ..."
        
        if ! parted -s "$disk_path" resizepart "$extended_partition" 100% 2>/dev/null; then
            log_error "扩展扩展分区失败"
            return 1
        fi
        
        log_info "扩展逻辑分区 $partition_number ..."
        if ! parted -s "$disk_path" resizepart "$partition_number" 100% 2>/dev/null; then
            log_error "扩展逻辑分区失败"
            return 1
        fi
    else
        # 直接扩展主分区
        if ! parted -s "$disk_path" resizepart "$partition_number" 100% 2>/dev/null; then
            log_error "扩展分区失败"
            return 1
        fi
    fi
    
    # 4. 更新内核分区表
    log_info "更新内核分区表..."
    partprobe "$disk_path" 2>/dev/null || true
    
    # 5. 扩展物理卷
    log_info "扩展物理卷 $partition_path ..."
    if ! pvresize "$partition_path" 2>/dev/null; then
        log_error "扩展物理卷失败"
        return 1
    fi
    
    # 6. 获取卷组信息
    local vg_name=$(pvs --noheadings -o vg_name "$partition_path" 2>/dev/null | tr -d ' ')
    if [ -z "$vg_name" ]; then
        log_error "未找到卷组"
        return 1
    fi
    
    log_info "卷组: $vg_name"
    
    # 7. 显示卷组信息
    log_info "卷组信息:"
    vgdisplay "$vg_name" 2>/dev/null
    echo ""
    
    # 8. 查找根逻辑卷
    local root_lv=$(lvs --noheadings -o lv_name "$vg_name" 2>/dev/null | grep -E "(root|main)" | head -1 | tr -d ' ')
    if [ -z "$root_lv" ]; then
        log_warning "未找到根逻辑卷，显示所有逻辑卷："
        lvs "$vg_name" 2>/dev/null
        echo ""
        echo "请选择要扩展的逻辑卷："
        local -a lv_list
        while IFS= read -r lv; do
            lv_list+=("$lv")
        done < <(lvs --noheadings -o lv_name "$vg_name" 2>/dev/null | tr -d ' ')
        
        if [ ${#lv_list[@]} -eq 0 ]; then
            log_error "未找到逻辑卷"
            return 1
        fi
        
        local i=1
        for lv in "${lv_list[@]}"; do
            echo "$i) $lv"
            ((i++))
        done
        
        echo -n "请选择逻辑卷 (1-${#lv_list[@]}): "
        read -r lv_choice
        
        if [[ "$lv_choice" =~ ^[0-9]+$ ]] && [ "$lv_choice" -ge 1 ] && [ "$lv_choice" -le ${#lv_list[@]} ]; then
            root_lv="${lv_list[$((lv_choice-1))]}"
        else
            log_error "无效选择"
            return 1
        fi
    fi
    
    log_info "目标逻辑卷: $root_lv"
    
    # 9. 扩展逻辑卷
    log_info "扩展逻辑卷 $root_lv ..."
    if ! lvextend -l +100%FREE "/dev/$vg_name/$root_lv" 2>/dev/null; then
        log_error "扩展逻辑卷失败"
        return 1
    fi
    
    # 10. 扩展文件系统
    local lv_device="/dev/mapper/${vg_name}-${root_lv}"
    log_info "扩展文件系统 $lv_device ..."
    
    # 检测文件系统类型
    local fs_type=$(blkid -o value -s TYPE "$lv_device" 2>/dev/null)
    log_info "文件系统类型: $fs_type"
    
    case "$fs_type" in
        ext2|ext3|ext4)
            if ! resize2fs "$lv_device" 2>/dev/null; then
                log_error "扩展ext文件系统失败"
                return 1
            fi
            ;;
        xfs)
            if ! xfs_growfs "$lv_device" 2>/dev/null; then
                log_error "扩展XFS文件系统失败"
                return 1
            fi
            ;;
        *)
            log_warning "不支持的文件系统类型: $fs_type"
            log_warning "请手动扩展文件系统"
            ;;
    esac
    
    # 11. 验证扩容结果
    log_success "扩容完成！"
    echo ""
    log_info "扩容后的磁盘使用情况:"
    df -h | grep -E "(Filesystem|/dev/mapper|/dev/$disk_name)"
    echo ""
    
    log_info "最终分区布局:"
    lsblk "$disk_path" 2>/dev/null
    echo ""
    
    log_success "硬盘扩容完成！"
}

# 主程序循环
main() {
    # 初始化
    initialize
    
    # 主菜单循环
    while true; do
        show_menu
        echo -n "请输入选择 (1-10, all, menu, q): "
        read -r choice
        
        case $choice in
            1)
                option_1_sources_proxy
                ;;
            2)
                option_2_hostname
                ;;
            3)
                option_3_dev_tools
                ;;
            4)
                option_4_git
                ;;
            5)
                option_5_ohmyzsh
                ;;
            6)
                option_6_volta
                ;;
            7)
                option_7_conda
                ;;
            8)
                option_8_docker
                ;;
            9)
                option_9_config
                ;;
            10)
                option_10_disk_expand
                ;;
            "all"|"ALL")
                install_all
                break
                ;;
            "menu"|"MENU")
                continue
                ;;
            "q"|"Q"|"quit"|"exit")
                log_info "感谢使用，再见！"
                exit 0
                ;;
            *)
                log_warning "无效选择，请重新输入"
                sleep 2
                ;;
        esac
    done
}

# 启动主程序
main

