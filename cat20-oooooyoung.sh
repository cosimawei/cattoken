Crontab_file="/usr/bin/crontab"
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="[${Green_font_prefix}信息${Font_color_suffix}]"
Error="[${Red_font_prefix}错误${Font_color_suffix}]"
Tip="[${Green_font_prefix}注意${Font_color_suffix}]"

check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限), 无法继续操作, 请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

install_env_and_full_node() {
    check_root
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl tar wget clang pkg-config libssl-dev jq build-essential git make ncdu unzip zip docker.io -y
    VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
    DESTINATION=/usr/local/bin/docker-compose
    sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
    sudo chmod 755 $DESTINATION

    sudo apt-get install npm -y
    sudo npm install n -g
    sudo n stable
    sudo npm i -g yarn

    git clone https://github.com/CATProtocol/cat-token-box
    cd cat-token-box
    sudo yarn install
    sudo yarn build

    cd ./packages/tracker/
    sudo chmod 777 docker/data
    sudo chmod 777 docker/pgdata
    sudo docker-compose up -d

    cd ../../
    sudo docker build -t tracker:latest .
    sudo docker run -d \
        --name tracker \
        --add-host="host.docker.internal:host-gateway" \
        -e DATABASE_HOST="host.docker.internal" \
        -e RPC_HOST="host.docker.internal" \
        -p 3000:3000 \
        tracker:latest
    echo '{
      "network": "fractal-mainnet",
      "tracker": "http://127.0.0.1:3000",
      "dataDir": ".",
      "maxFeeRate": 30,
      "rpc": {
          "url": "http://127.0.0.1:8332",
          "username": "bitcoin",
          "password": "opcatAwesome"
      }
    }' > ~/cat-token-box/packages/cli/config.json

    echo '#!/bin/bash

    command="sudo yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5"

    while true; do
        $command

        if [ $? -ne 0 ]; then
            echo "命令执行失败，退出循环"
            exit 1
        fi

        sleep 1
    done' > ~/cat-token-box/packages/cli/mint_script.sh
    chmod +x ~/cat-token-box/packages/cli/mint_script.sh
}

create_wallet() {
  echo -e "\n"
  cd ~/cat-token-box/packages/cli
  sudo yarn cli wallet create
  echo -e "\n"
  sudo yarn cli wallet address
  echo -e "请保存上面创建好的钱包地址、助记词"
}


delete_wallet() {
  echo -e "\n"
  cd ~/cat-token-box/packages/cli

  # 生成一个基于毫秒级时间戳的备份文件名
  backup_file="wallet_$(date +%s%3N).json"
  
  # 备份 wallet.json
  sudo cp wallet.json $backup_file
  echo -e "钱包已备份为 $backup_file"

  # 删除原始的 wallet.json
  sudo rm -f wallet.json
  echo -e "\n"
  echo -e "钱包删除成功"

  # 创建新钱包
  sudo yarn cli wallet create
  echo -e "\n"

  # 显示新钱包地址
  sudo yarn cli wallet address
  echo -e "请保存上面创建好的钱包地址、助记词"
}

start_mint_cat() {
  cd ~/cat-token-box/packages/cli
  bash ~/cat-token-box/packages/cli/mint_script.sh
}

check_node_log() {
  docker logs -f --tail 100 tracker
}

check_wallet_balance() {
  cd ~/cat-token-box/packages/cli
  sudo yarn cli wallet balances
}

modify_gas_value() {
  cd ~/cat-token-box/packages/cli
  read -e -p "请输入新的 maxFeeRate 值: " new_max_fee_rate

  # 使用 jq 工具修改 config.json 中的 maxFeeRate 值
  sudo jq --argjson rate "$new_max_fee_rate" '.maxFeeRate = $rate' config.json > config_tmp.json && mv config_tmp.json config.json

  echo -e "maxFeeRate 已修改为 $new_max_fee_rate"
}


list_wallet_files() {
  echo -e "\n"
  cd ~/cat-token-box/packages/cli

  # 查找并列出符合条件的文件，包括 wallet.json 和 wallet_*.json
  for file in wallet.json wallet_*.json; do
    if [ -f "$file" ]; then
      echo "文件名: $(basename "$file")"
      echo "内容:"
      cat "$file"
      echo "-----------------------------"
    fi
  done
}

echo && echo -e " ${Red_font_prefix}dusk_network 一键安装脚本${Font_color_suffix} by \033[1;35moooooyoung\033[0m
此脚本完全免费开源, 由推特用户 ${Green_font_prefix}@ouyoung11开发${Font_color_suffix}, 
欢迎关注, 如有收费请勿上当受骗。
 ———————————————————————
 ${Green_font_prefix} 1.安装依赖环境和全节点 ${Font_color_suffix}
 ${Green_font_prefix} 2.创建钱包 ${Font_color_suffix}
 ${Green_font_prefix} 3.开始 mint cat ${Font_color_suffix}
 ${Green_font_prefix} 4.查看节点同步日志 ${Font_color_suffix}
 ${Green_font_prefix} 6.备份后删除并创建新钱包 ${Font_color_suffix}
 ${Green_font_prefix} 7.修改 gas 值 ${Font_color_suffix}
 ${Green_font_prefix} 8.列出钱包文件 ${Font_color_suffix}
 ———————————————————————" && echo
read -e -p " 请参照上面的步骤，请输入数字:" num
case "$num" in
1)
    install_env_and_full_node
    ;;
2)
    create_wallet
    ;;
3)
    start_mint_cat
    ;;
4)
    check_node_log
    ;;
5)
    check_wallet_balance
    ;;
6)
    delete_wallet
    ;;	
7)
    modify_gas_value
    ;;
8)
    list_wallet_files
    ;;
*)
    echo
    echo -e " ${Error} 请输入正确的数字"
    ;;
esac
