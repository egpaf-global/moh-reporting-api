-- Create the 'databases' database if it does not exist
CREATE DATABASE IF NOT EXISTS `databases`;

-- Switch to the 'databases' database
USE `databases`;

-- Create the 'databases' table
CREATE TABLE IF NOT EXISTS `databases` (
    `site_id` INT NOT NULL PRIMARY KEY,
    `database` VARCHAR(255) NOT NULL UNIQUE,
    `username` VARCHAR(255),
    `password` VARCHAR(255),
    `active` TINYINT(1) DEFAULT 0,
    `etl_status` VARCHAR(100),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
