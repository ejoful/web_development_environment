#!/bin/sh
## Upgrading MariaDB
## brew update
## brew upgrade mariadb

# 安装 Homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

sudo chown -R $(whoami) /usr/local/share/man/man8
brew install cmake
# 安装 locate 命令
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.locate.plist
# 安装 mariadb
brew install mariadb
# 安装 phpmyadmin
brew install phpmyadmin
# 修改 mariadb 配置文件
sudo sed -i '.'$(date "+%Y-%m-%d")'.bak' \
 -e "1i\\
# 添加编码配置\\
[mysql]\\
default-character-set=utf8\\
[mysqld]\\
# 设置时区为东八区\\
default-time-zone='+08:00'\\
" /usr/local/etc/my.cnf
# 启动 mariadb 并加入服务
brew services start mariadb

sudo apachectl -k stop
sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist

brew install php
brew services start php
brew install httpd24

current_user=$(whoami)
php7_module_path=$(find /usr/local/Cellar -name libphp7.so)
# 修改apache配置文件
sudo sed -i '.'$(date "+%Y-%m-%d")'.bak' \
 -e "s/Listen 8080/Listen 80/g" \
 -e 's#AllowOverride None#AllowOverride All#g' \
 -e 's/#LoadModule rewrite_module/LoadModule rewrite_module/g' \
 -e 's|#Include /usr/local/etc/httpd/extra/httpd-vhosts.conf|Include /usr/local/etc/httpd/extra/httpd-vhosts.conf|g' \
 -e "s/User _www/User $current_user/g" \
 -e 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/g' \
 -e '/#ServerName www.example.com:8080/a\
ServerName localhost\
' \
 -e "$a\
Include /usr/local/etc/httpd/user/*.conf\
LoadModule php7_module $php7_module_path\
<FilesMatch \\.php$>\
SetHandler application/x-httpd-php\
</FilesMatch>\
Alias /phpmyadmin /usr/local/share/phpmyadmin\
<Directory /usr/local/share/phpmyadmin/>\
\ \ \ \ Options Indexes FollowSymLinks MultiViews\
\ \ \ \ AllowOverride All\
\ \ \ \ <IfModule mod_authz_core.c>\
\ \ \ \ \ \ \ \ Require all granted\
\ \ \ \ </IfModule>\
\ \ \ \ <IfModule !mod_authz_core.c>\
\ \ \ \ \ \ \ \ Order allow,deny\
\ \ \ \ \ \ \ \ Allow from all\
\ \ \ \ </IfModule>\
</Directory>\
\
\
" /usr/local/etc/httpd/httpd.conf
sudo mkdir -p /usr/local/etc/httpd/user
sudo chown -R $current_user:admin /usr/local/etc/httpd/user
sudo echo '

# yii 网站虚拟主机配置
<VirtualHost *:80>
    DocumentRoot "/usr/local/var/www/website/run/frontend/web"
    ServerName www.website.com
    ErrorLog "/usr/local/var/log/httpd/website-error_log"
    CustomLog "/usr/local/var/log/httpd/website-access_log" common
    <Directory "/usr/local/var/www/website/run/frontend/web">
        # 开启 mod_rewrite 用于美化 URL 功能的支持（译注：对应 pretty URL 选项）
        RewriteEngine on
        # 如果请求的是真实存在的文件或目录，直接访问
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        # 如果请求的不是真实文件或目录，分发请求至 index.php
        RewriteRule . index.php
    </Directory>
</VirtualHost>

<VirtualHost *:80>
    DocumentRoot "/usr/local/var/www/website/run/backend/web"
    ServerName ht.website.com
    ErrorLog "/usr/local/var/log/httpd/ht.website-error_log"
    CustomLog "/usr/local/var/log/httpd/ht.website-access_log" common
    <Directory "/usr/local/var/www/website/run/backend/web">
        # 开启 mod_rewrite 用于美化 URL 功能的支持（译注：对应 pretty URL 选项）
        RewriteEngine on
        # 如果请求的是真实存在的文件或目录，直接访问
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        # 如果请求的不是真实文件或目录，分发请求至 index.php
        RewriteRule . index.php
    </Directory>
</VirtualHost>

'>/usr/local/etc/httpd/user/yii_website.conf

sudo sed -i -e '$a\
127.0.0.1 www.website.com ht.website.com' /etc/hosts

sudo sed -i -e 's/;pcre.jit=1/pcre.jit=0/g' /usr/local/etc/php/7.3/php.ini

sudo sed -i '.'$(date "+%Y-%m-%d")'.bak' \
 -e '$a\
<VirtualHost \*:80>\
\ \ \ \ DocumentRoot "/usr/local/var/www"\
\ \ \ \ ServerName localhost\
\ \ \ \ ErrorLog "/usr/local/var/log/httpd/localhost-error_log"\
\ \ \ \ CustomLog "/usr/local/var/log/httpd/localhost-access_log" common\
</VirtualHost>\
\
' /usr/local/etc/httpd/extra/httpd-vhosts.conf

#启动apache
brew services start httpd


# 设置文件权限
# 1.将您的用户添加到 _www。
sudo dscl . -append /Groups/_www GroupMembership $current_user
# 2.将 /usr/local/var/www 及其内容的组所有权更改到 _www 组
sudo chown -R $current_user:_www /usr/local/var/www
# 3.要添加组写入权限以及设置未来子目录上的组 ID，请更改 /usr/local/var/www 及其子目录的目录权限。
sudo chmod 2775 /usr/local/var/www
find /usr/local/var/www -type d -exec sudo chmod 2775 {} \;
# 4.要添加组写入权限，请递归地更改 /usr/local/var/www 及其子目录的文件权限：
find /usr/local/var/www -type f -exec sudo chmod 0664 {} \;



# 在用户主目录下创建到 /usr/local/var/www 的软链接
sudo ln -s /usr/local/var/www ~/html

# 测试您的 LAMP Web 服务器
sudo echo "<?php phpinfo(); " > ~/html/phpinfo.php




