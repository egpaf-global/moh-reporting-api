# CDR REPORTING API
This is the Central Data Repository CDR reporting API that has been decoupled from the [MALAWI EMR API](https://github.com/HISMalawi/BHT-EMR-API). This can only handle to run reports and can not be used for data capturing.

## Requirements
The following are the requirements:
* Ruby 3.2.0 +
* MySQL 5.6 +
* Postgres 14 +
* Unix Enviroment / Docker Environment

## Setup
To setup this application to be working with CDR follow these steps.

### Configuration
Copy the following configuration files and adjust the settings based on your server

```bash
cp config/cable.yml.example config/cable.yml
cp config/database.yml.example config/database.yml
cp config/storage.yml.example config/storage.yml
cp config/locales/en.yml.example config/locales/en.yml
```

### Gemfile
This is meant to work with both MySQL and Postgres. So you will need to enable PG if using Postgres by uncommenting the line. If you do this then MYSQL should be uncommented out. Otherwise MySQL is enabled by default.

### Install Bundler
Install bundler with

```bash
  gem install bundler
```

### Installing Dependencies
To install dependencies
```bash
bundle i
```

### MySQL Functions and Schemas
In order to ensure that the CDR has valid views and functions please run this command below. 
```bash
bin/update_metadata.sh development
```
You can substitute development with production, test. Valid environmenst ```development|production|test```
Currently this is capable running in development mode. Future iterations will handle production mode.

## Developers
At a minimum try to stick to the following:

- Use 2 spaces (not tab configured to take 2 spaces) for indentation
- Methods should normally not exceed 12 lines (you can go beyond this with good reason)
- Prefer `&&/||` over `and/or`
- Error should never pass silently, if you handle an exception, log the error you just handled
- Related to the point above, avoid inline rescue statements
- Use guard statements when validating a variable, if you can't, consider moving the validation logic to a method
- Package your business logic in services where possible. These are located in `app/services` directory.
  Try to keep them [SOLID](https://en.wikipedia.org/wiki/SOLID) please.
- If you know it's a hack please leave a useful comment
- If what you wrote doesn't make sense, revise until it does else leave useful comments and a unit test
- If a file exceeds 120 lines, you better have a good reason as to why it is so
- This is Ruby, it shouldn't read like Java, see [Writing Beautiful Ruby](https://medium.com/the-renaissance-developer/idiomatic-ruby-1b5fa1445098)

See the following for more:

- [Rubocop style guide](https://github.com/rubocop-hq/ruby-style-guide)

## Endpoints
These are the endpoints currently supported
- Locations: ```{host}:{port}/api/v1/locations/{query_parameters}``` The query parameters are for pagination
- Reports: ```{host}:{port}/api/v1/reports/{report_name}/{query_parameters}```

## To create a the DRC datalake database:
 ```
 pv db/datalake_structure.sql | mysql -u USERNAME -p PASSWORD DATABASE_NAME
 ```