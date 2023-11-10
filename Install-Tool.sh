#!/bin/bash

# 设置JDK版本和下载地址的基本信息
jdk_versions=("8" "11" "17" "21") # 可以添加更多版本
jdk_detailed_versions=("OpenJDK8U-jdk_x64_linux_hotspot_8u392b08" "OpenJDK11U-jdk_x64_linux_hotspot_11.0.21_9" "OpenJDK17U-jdk_x64_linux_hotspot_17.0.9_9" "OpenJDK21U-jdk_x64_linux_hotspot_21.0.1_12")
jdk_folder_names=("jdk8u392-b08" "jdk-11.0.21+9" "jdk-17.0.9+9" "jdk-21.0.1+12")
download_url="https://mirrors.tuna.tsinghua.edu.cn/Adoptium/"

# 检查是否具有root权限
if [ "$EUID" -ne 0 ]; then
  echo "请以root权限运行此脚本"
  exit 1
fi

# 安装wget工具，如果没有的话
if ! command -v wget &> /dev/null; then
  apt-get update
  apt-get install -y wget
fi

echo "Please choose the software you are going to install:"
PS3="Please choose the software you are going to install: (Use digit and split with ',') : "
options=("Java" "MySQL" "Redis" "RabbitMQ" "None")
select opt in "${options[@]}"; do
  case "$opt" in
    "Java")
      echo "Installing Java..."
      # jdk8 : https://mirrors.tuna.tsinghua.edu.cn/Adoptium/8/jdk/x64/linux/OpenJDK8U-jdk_x64_linux_hotspot_8u392b08.tar.gz
      # jdk11 : https://mirrors.tuna.tsinghua.edu.cn/Adoptium/11/jdk/x64/linux/OpenJDK11U-jdk_x64_linux_hotspot_11.0.21_9.tar.gz
      # jdk17 : https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/linux/OpenJDK17U-jdk_x64_linux_hotspot_17.0.9_9.tar.gz
      # jdk 21 : https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/x64/linux/OpenJDK21U-jdk_x64_linux_hotspot_21.0.1_12.tar.gz

      # 提示用户选择主Java版本
      echo "Please select the main java version"
      for i in "${!jdk_versions[@]}"; do
        echo "$((i+1)). jdk - ${jdk_versions[i]}"
      done

      read -p "Please enter your choice (1, 2, 3, ...): " choice

      # 验证选择是否有效
      if [ "$choice" -ge 1 ] && [ "$choice" -le ${#jdk_versions[@]} ]; then
        selected_version="${jdk_versions[choice-1]}"
        echo "You chose $selected_version"
      else
        echo "Illegal. Exiting.."
        exit 1
      fi

      mkdir -p /home/jdk

      # 循环下载和配置每个版本的JDK
      for i in $(seq 0 `expr ${#jdk_versions[@]} - 1`); do
        jdk_version=${jdk_versions[i]}
        jdk_detailed_version=${jdk_detailed_versions[i]}
        jdk_folder_name=${jdk_folder_names[i]}

        # 下载JDK
        download_link="${download_url}${jdk_version}/jdk/x64/linux/${jdk_detailed_version}.tar.gz"
        wget "$download_link" -O "/tmp/${jdk_version}.tar.gz"

        # 解压JDK
        tar -xf "/tmp/${jdk_version}.tar.gz" -C "/home/jdk"

        # 配置环境变量
        if [ "$selected_version" = "$jdk_version" ]; then
          echo "export JAVA_HOME=/home/jdk/${jdk_folder_name}" >> /etc/profile
          echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile
        fi

        # 使用update-alternatives进行版本管理
        update-alternatives --install /usr/bin/java java "/home/jdk/${jdk_folder_name}/bin/java" ${i}
        update-alternatives --install /usr/bin/javac javac "/home/jdk/${jdk_folder_name}/bin/javac" ${i}
        update-alternatives --install /usr/bin/jar jar "/home/jdk/${jdk_folder_name}/bin/jar" ${i}
        update-alternatives --set java "/home/jdk/${jdk_folder_name}/bin/java"
        update-alternatives --set javac "/home/jdk/${jdk_folder_name}/bin/javac"
        update-alternatives --set jar "/home/jdk/${jdk_folder_name}/bin/jar"
      done

      # 更新update-alternatives配置
      update-alternatives --config java
      update-alternatives --config javac
      update-alternatives --config jar

      source /etc/profile

      # 清除临时文件
      rm -f /tmp/*.tar.gz

      echo "Java is set up. Use 'update-alternatives --config' to change java version."
      ;;
    "MySQL")
      echo "Installing MySQL..."

      # 下载MySQL APT仓库配置文件
      mysql_apt_config_url="https://dev.mysql.com/get/mysql-apt-config_0.8.28-1_all.deb"
      wget "$mysql_apt_config_url"

      # 安装APT仓库配置文件
      dpkg -i mysql-apt-config_0.8.28-1_all.deb

      # 更新软件包列表
      apt-get update

      # 安装MySQL服务器
      apt-get install mysql-server

      # 清除下载的APT仓库配置文件
      rm mysql-apt-config_0.8.28-1_all.deb

      # 输出安装完成信息
      echo "MySQL Installed."
      ;;
    "Redis")
      echo "Installing Redis..."
      # 在此处添加安装 Redis 的命令，例如：apt-get install -y redis-server
      curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg

      echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

      sudo apt-get update
      sudo apt-get install redis

      echo "Redis Installed."
      ;;
    "RabbitMQ")
      echo "Installing RabbitMQ..."
      # 在此处添加安装 RabbitMQ 的命令，例如：apt-get install -y rabbitmq-server
      sudo apt-get install curl gnupg apt-transport-https -y

      ## Team RabbitMQ's main signing key
      curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null
      ## Community mirror of Cloudsmith: modern Erlang repository
      curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null
      ## Community mirror of Cloudsmith: RabbitMQ repository
      curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg > /dev/null

      ## Add apt repositories maintained by Team RabbitMQ
      sudo tee /etc/apt/sources.list.d/rabbitmq.list
      ## Update package indices
      sudo apt-get update -y

      ## Install Erlang packages
      sudo apt-get install -y erlang-base \
                              erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                              erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                              erlang-runtime-tools erlang-snmp erlang-ssl \
                              erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

      ## Install rabbitmq-server and its dependencies
      sudo apt-get install rabbitmq-server -y --fix-missing

      rabbitmq-plugins enable rabbitmq_management

      read -p "Please enter your rabbitMQ admin password: " password
      # create a user
      rabbitmqctl add_user admin $password
      # tag the user with "administrator" for full management UI and HTTP API access
      rabbitmqctl set_user_tags admin administrator
      rabbitmqctl set_permissions -p "/" admin ".*" ".*" ".*"

      echo "RabbitMQ Installed."
      ;;
    "None")
      echo "Finish Installation."
      break
      ;;
    *) echo "Invalid Choice.";;
  esac
done