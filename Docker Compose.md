[TOC]

# Docker Compose

## 一、简介

1、Docker Compose是一个工具；

2、这个工具可以通过一个yaml文件定义多容器的docker应用；

3、通过一条命令就可以根据yaml文件的定义去创建或者管理多个容器。

**注意：**version 2只支持单机部署，version 3支持集群部署。

## 二、常用命令

1、docker-compose up：启动并运行容器，默认使用当前目录下的docker-compose.yml文件

2、docker-compose up	

​	 -d 后台运行服务容器

​	-build 在启动容器前构建服务镜像

3、docker-compose down  停用移除所有容器以及网络相关

4、docker-compose ps 列出项目中所有的容器

5、docker-compose logs 查看服务容器的输出

6、docker-compose restart 重启项目中的服务

7、docker-compose rm	删除所有（停止状态的）服务容器

8、docker-compose start 启动已存在的服务容器

9、docker-compose stop 停止运行的容器

10、docker-compose run 在指定容器上执行一个命令

11、docker-compose pause 暂停一个服务容器

12、docker-compose uppause 恢复处于暂停状态中的服务

## 三、安装docker compose

两种最新的docker安装方式

### 1.从github上下载docker-compose二进制文件安装

- 下载最新版的docker-compose文件 

```bash
sudo curl -L https://github.com/docker/compose/releases/download/1.16.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
```

​    若是github访问太慢，可以用daocloud下载

```bash
sudo curl -L https://get.daocloud.io/docker/compose/releases/download/1.25.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
```

- 添加可执行权限 

  ```bash
  sudo chmod +x /usr/local/bin/docker-compose
  ```

- 测试安装结果 

  ```bash
  $ docker-compose --version
  
  docker-compose version 1.16.1, build 1719ceb
  ```

### 2.pip安装

```bash
sudo pip install docker-compose
```

## 四、模板文件简介

| version: '3'<br/>services:<br/>    db_redis:<br/>        image: redis<br/>        tty: true<br/>        volumes:<br/>            - ./data:/data<br/>            - ./redis.conf:/usr/local/etc/redis/redis.conf<br/>        ports:<br/>            - "16378:6379"<br/>        restart: always<br/>        command: redis-server /usr/local/etc/redis/redis.conf<br/>        networks:<br/>            - yaxt_net<br/>networks:<br/>  yaxt_net:<br/>    external: true |
| ------------------------------------------------------------ |
| image: 指定服务的镜像名称或者镜像ID                          |
| volumes：将主机的数据卷或者文件挂载到容器里                  |
| ports：用于映射端口的标签                                    |
| restart：<br />   no：是默认的重启策略，任何情况下都不会重启容器<br />   always：容器总是重新启动。<br />   on-failure：在容器非正常退出时才会重启容器<br />   unless-stopped：容器退出时总是重启容器<br /> |
| environment：添加环境变量                                    |
| networks：配置容器连接的网络                                 |
| command：覆盖容器启动的默认命令                              |
| tty：防止容器启动又停止的情况                                |

