#!/bin/bash 

function print_color(){ 
    #A function that takes a color name as the first arg and the content to print as the second arg
    NC='\033[0m' 

    case $1 in 
        "green") COLOR='\033[0;32m';;
        "red") COLOR='\033[0;31m';;
        "*") COLOR=$NC;;
    esac 

    echo -e "${COLOR}${2}${NC}" 
} 

function check_service_status(){ 
    #A function that tests if a provided service name is active on the system
  service_is_active=$(sudo systemctl is-active $1) 
  if [ $service_is_active = "active" ] 
  then 
    print_color "green" "$1 is active and running" 
  else 
    print_color "red" "$1 is not active/running" 
    exit 1 
  fi 
} 


function is_firewalld_rule_configured(){ 
  firewalld_ports=$(sudo firewall-cmd --list-all --zone=public | grep ports) 

  if [[ $firewalld_ports == *$1* ]] 
  then 
    print_color "green" "FirewallD has port $1 configured"
  else 
    print_color "red" "FirewallD port $1 is not configured" 
    exit 1 
  fi 
} 


function check_item(){
    if [[ $1 = *$2* ]]
    then
        print_color "green" "Item ${2} found in web application"
    else
        print_color "red" "Item ${2} not found in web application"
    fi
}


# Install firewalld 
print_color "green" "----- Installing firewalld service -----" 
sudo yum install -y firewalld 

print_color "green" "----- Enabling firewalld service -----" 
sudo systemctl start firewalld 
sudo systemctl enable firewalld 
sudo systemctl status firewalld 

  
# Check if firewalld service is running 
check_service_status firewalld 

  
#Install and enable mariadb 
print_color "green" "----- Installing mariadb-server -----" 
sudo yum install -y mariadb-server 

print_color "green" "----- Enabling MaridaDB service -----" 
sudo systemctl start mariadb 
sudo systemctl enable mariadb 
check_service_status mariadb
  
print_color "green" "----- Configuring firewalld for MariaDB server" 
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp 
sudo firewall-cmd --reload 
is_firewalld_rule_configured 3306

  
#Create and configure DB
print_color "green" "----- Creating setup-db script -----" 
cat > setup-db.sql <<-EOF 
    CREATE DATABASE ecomdb; 
    CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword'; 
    GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost'; 
    FLUSH PRIVILEGES; 
EOF

print_color "green" "----- Creating DB using the setup-db script -----" 
sudo mysql < setup-db.sql 
  

#Populate DB
print_color "green" "----- Creating db-load script -----" 
cat > db-load-script.sql <<-EOF
    USE ecomdb; 
    CREATE TABLE products (
        id mediumint(8) unsigned NOT NULL auto_increment,
        Name varchar(255) default NULL,
        Price varchar(255) default NULL,
        ImageUrl varchar(255) default NULL,
        PRIMARY KEY (id)
    ) AUTO_INCREMENT=1;

    INSERT INTO products (Name,Price,ImageUrl) VALUES 
        ("Laptop","100","c-1.png"),
        ("Drone","200","c-2.png"),
        ("VR","300","c-3.png"),
        ("Tablet","50","c-5.png"),
        ("Watch","90","c-6.png"),
        ("Phone Covers","20","c-7.png"),
        ("Phone","80","c-8.png"),
        ("Laptop","150","c-4.png");

EOF

print_color "green" "----- Populating DB using the db-load script -----" 
sudo mysql < db-load-script.sql 


#Install and configure Apache web server 
print_color "green" "----- Installing httpd server -----" 
sudo yum install -y httpd php php-mysqlnd 

print_color "green" "----- Configuring firewalld to enable port 80 -----" 
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp 
sudo firewall-cmd --reload 
is_firewalld_rule_configured 80


print_color "green" "----- Configuring httpd.conf to use index.php instead of index.html -----" 
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf 

  
print_color "green" "----- Enabling apache web-server -----" 
sudo systemctl start httpd 
sudo systemctl enable httpd 

print_color "green" "----- Download .php project code -----" 
sudo yum install -y git 
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/ 
sudo sed -i 's#// \(.*mysqli_connect.*\)#\1#' /var/www/html/index.php 
sudo sed -i 's#// \(\$link = mysqli_connect(.*172\.20\.1\.101.*\)#\1#; s#^\(\s*\)\(\$link = mysqli_connect(\$dbHost, \$dbUser, \$dbPassword, \$dbName);\)#\1// \2#' /var/www/html/index.php 


print_color "green" "----- Updating index.php file to use localhost -----" 
sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php 

#Test if the web application is up and running.
print_color "green" "----- Testing script -----" 
web_page=$(curl http://localhost)

#Test if there are relevant items in the web application.
for item in Laptop Drone VR Watch Phone Tablet Goat
do 
  check_item "$web_page" $item 
done 

