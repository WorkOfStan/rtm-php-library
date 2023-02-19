<?php

/**
 * This is a specimen content of config.local.php:
 */

/**
 * Debugging
 */
//ini_set('display_errors', '1'); // allow ONLY in your own development environment
//define('DEBUG_VERBOSE', true); // show all debug messages to the admin

/**
 * Database
 */
//$phinxEnvironment = 'development'; // redefine phinx.yml environment of database

/**
 * If MySQL timezone differs from PHP timezone settings
 * SELECT @@global.time_zone, @@session.time_zone, @@system_time_zone
 * vs
 * Default timezone in php_info();
 *
 * Meaning that creating item and adding inventory leads to a fail, fix by harmonising the timezones:
 */
//date_default_timezone_set('Europe/Prague');

