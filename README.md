# Drupal Provision
Drupal Provision is a command line tool was created to expedite the process of
provisioning a new production environment for a Drupal based website.  It can be 
used to install all the required Linux packages, create an optional development
environment, secure all non-production VirtualHosts with basic authentication,
and create all needed databases. This script will also preconfigure the Apache
SSL configuration by adding all required SSL directives to the production
VirtualHost file, if needed.


**Overview:**
- Install LAMP Stack and additional packages useful for hosting a Drupal website. 
- Configure Apache and install new VirtualHosts for top level domain hosting.
- Create optional development environments for production domains.
  -  Development environments follow a `dev.mywebsite.com` pattern.
  -  Basic authentication for all non-production environments.
- Create new database(s) with a randomly generated secure password.
- Create optional VirtualHost configuration for SSL for production environments.
  

## Compatability
- Debian 8
- Apache 2.4
- PHP 5.6
- MySQL 5.5
- Composer 1.4
- Drupal 7
- Drupal 8
- Drush 8.1 

## Installation

**Installation:**
1. Clone the repository: `git clone git@github.com:willjackson/drupal-provision.git /usr/local/src/drupal-provision`
2. Make script executeble: `sudo chmod +x /usr/local/src/drupal-provision/drupal-provision.sh`
3. Make the script available globally: `ln -s /usr/local/src/drupal-provision/drupal-provision.sh /usr/local/bin/drupal-provision`

## Usage

- Basic usage:
  - `drupal-provision` 

- Specify the top-level domain for the new VirtualHost:
  - `drupal-provision mywebsite.com`
  - `drupal-provision www.website.com`
 

**Running the script:**

1. Provide MySQL Root Password to configure databases.
   1.  *If you are provisioning a server for the first time, the password will be
   used as the MySQL Root Password.*
2. Optionally provision the server, by installing required Linux packages for
Drupal hosting.
3. Create optional database for new environments.
4. Create an optional development environment for the production VirtualHost.

Once completed, you will be presented with details on the new environments.

## Configuration

***Setting your MySQL Password***

- To include your mysql root password, uncomment the `mysql_root_pw` variable
in the Global Variables section of the script.

***Apache Base Directory for VirtualHosts***

- By default, VirtualHosts will be served from `/srv/www/`.  To modify the base
directory, update the `apache_directory` variable in the Global Variables
section of the script.

***Basic Authentication***

- Basic authentication is enabled globally and overriden for production environments.
- Credentials are stored in `/etc/htpasswd/.htpasswd`.
- You may also refer to the
[Apache documentation](https://httpd.apache.org/docs/current/programs/htpasswd.html)
for more information.
  
***SSL for Production Environments***

- When you select to configure SSL for production, the VirtualHost file will simply
contain the base structure needed to enable SSL for that environment.  Refer to
this my documentation for
[configuring SSL for Apache on Debian or Ubuntu](http://willjackson.org/blog/configuring-ssl-apache-debian-or-ubuntu)
for more information on configuring SSL.

***VirtualHost Configuration***

- Each VirtualHost created will have a configuration file located in `/etc/apache2/sites-available/`.
