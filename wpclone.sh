#!/bin/bash


read -p "What is the source domain? " domain_source;

read -p "What is the destination domain? " domain_destination;

read -p "What is the destination Database? " dbname_destination;

read -p "What is the destination Database user? " dbuser_destination;

read -p "What is the destination Database Password? " dbpass_destination;


##### Checking The Source domain DB,Username,SiteURL,Docroot,User dir size


##### Checking for a Source domain Username 
    
    user_source=`/scripts/whoowns ${domain_source}`;
 
##### Checking what is the Source domain Docroot 
    
    docroot_source=`grep -e ^${domain_source}: /etc/userdatadomains | awk -F'==' '{print $5}'`;
 
##### Checking what is the source domain Database 
    
    dbname_source=`grep DB_NAME ${docroot_source}/wp-config.php | cut -d\' -f4`; prefix_source=$(grep ^\$table_prefix ${docroot_source}/wp-config.php | cut -d\' -f2); 
 
##### Checking what is the source domain SiteURL 
    
    siteurl_source=$(mysql -Nse 'select option_value from '${dbname_source}'.'${prefix_source}'options where option_name="siteurl"'); 
 
##### Stating the output for source domain  
    
    echo -e "\ncPanel username: ${user_source}\nDocument root: ${docroot_source}\nDatabase name: ${dbname_source}\nTable prefix: ${prefix_source}\nSiteurl: ${siteurl_source}" ; 
 
##### Checking the source domain Database Size  
    
    echo -e "\n##### Source Database Size ####" ; mysql -e 'SELECT table_schema '${dbname_source}', round(sum( data_length + index_length )/1024/1024,2) "DB Size (MB)", round(sum( data_free )/1024/1024,2) "Free Space (MB)" FROM information_schema.TABLES WHERE TABLE_SCHEMA="'$dbname_source'"'; 
 
##### Checkign the size of Source Domain Home Dir 
    
    echo -e "\nUser Dir Size" ; du -hxa --max-depth=1 /home/$user_source | sort -hr | head; 
 
######## Output for destination domain 

    echo -e "\nDestination domain Information";

##### Destination domain Username

    user_destination=`/scripts/whoowns ${domain_destination}`;

##### Destination domain Docroot

    docroot_destination=`grep -e ^${domain_destination}: /etc/userdatadomains | awk -F'==' '{print $5}'`;

##### Stating output for Destination domain 

    echo -e "\ncPanel username: ${user_destination}\nDocument root: ${docroot_destination}\nDatabase name: ${dbname_destination}\nDatabase Username: ${dbuser_destination} "; 

##### Destination domain Database Size 

    echo -e "\n##### Destination Database Size ####" ; mysql -e 'SELECT table_schema '${dbname_destination}', round(sum( data_length + index_length )/1024/1024,2) "DB Size (MB)", round(sum( data_free )/1024/1024,2) "Free Space (MB)" FROM information_schema.TABLES WHERE TABLE_SCHEMA="'$dbname_destination'"'; 

##### Destination domain home Dir size 

    echo -e "\nUser Dir Size" ; du -hxa --max-depth=1 /home/$user_destination | sort -hr | head;

##### Creating the Source/Destination Account backup 

    echo -e "\nCreating backups of Source and Destination " ;

    touch /home/$user_source/clonebackup.txt ; 
    
    touch /home/$user_destination/clonebackup.txt ;

    /scripts/pkgacct $user_source /home/$user_source/ > /home/$user_source/clonebackup.txt ;
    
    /scripts/pkgacct $user_destination /home/$user_destination/ > /home/$user_destination/clonebackup.txt ;

    echo -e "\nBackups are finished please review the following : " ; 

    tail -10 /home/$user_source/clonebackup.txt ; 
    
    tail -10 /home/$user_destination/clonebackup.txt ; 


##### Starting the clone proces 

##### Creating the RSYNC Report 

    touch /root/wpclonersyncreport.txt

    echo ; read -p "Please review the information above and if you agree type Yes/No? " Yes; 

##### Populating the Destination Database 

    mysqldump $dbname_source | mysql $dbname_destination ; 

    echo -e "\nDatabase has been cloned" ; 

##### Start the cloning via RSYNC 

    echo -e "\nCloning the content from Source to Destination" ;

    rsync -uavHP /$docroot_source/ /$docroot_destination/ > /root/wpclonereport.txt ;

##### Changing the permissions/ownership on destination 

    cd $docroot_destination ;

##### Changing file ownership on destination


    echo -e "\nChanging ownership on destination domain";
    
    find . -type f -exec chown $user_destination:$user_destination {} \;

##### Changing folder ownership on destination

    find . -type d -exec chown $user_destination:$user_destination {} \;
    
    chown $user_destination:nobody $docroot_destination ;

##### Search replace via Wp-cli 

    echo -e "\nSearch replace via WP-CLI on Destination Database";
	
	su - $user_destination -s /bin/bash -c "wp search-replace --path="$docroot_destination" --all-tables 'http://${domain_source}' 'http://${domain_destination}'" ;
	
	su - $user_destination -s /bin/bash -c "wp search-replace --path="$docroot_destination" --all-tables 'http://www.${domain_source}' 'http://www.${domain_destination}'" ;
	
	su - $user_destination -s /bin/bash -c "wp search-replace --path="$docroot_destination" --all-tables 'https://${domain_source}' 'https://${domain_destination}'" ;
	
	su - $user_destination -s /bin/bash -c "wp search-replace --path="$docroot_destination" --all-tables 'https://www.${domain_source}' 'https://www.${domain_destination}'" ; 

	
##### Placing correct credentials to wp-config.php on destination 
	
    echo -e "\nSetting destination database credentials to wp-config.php";
	
	sed -i "s/^.*DB_NAME.*$/define('DB_NAME', '$dbname_destination');/g" ${docroot_destination}/wp-config.php;
	
	sed -i "s/^.*DB_USER.*$/define('DB_USER', '$dbuser_destination');/g" ${docroot_destination}/wp-config.php ;
	
	sed -i "s/^.*DB_PASSWORD.*$/define('DB_PASSWORD', '$dbpass_destination');/g" ${docroot_destination}/wp-config.php ;	

##### Finished the Cloning 

    echo -e "\nThe cloning has been finished please review if everything is fine with the destination domain and dont forget to set up the wp-config with new DB credentials" ; 
