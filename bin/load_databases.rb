require 'yaml'
require 'parallel'
require 'fileutils'

# Method to load MySQL dumps into individual databases
def load_dumps_into_databases
  # Path to directory containing MySQL dump files
  dump_dir = YAML.load_file('config/application.yml')[:dump_source]

  # Destination directories for successful and failed loads
  success_dir = "#{Rails.root}/storage/success"
  failed_dir = "#{Rails.root}/storage/failed"

  # Create destination directories if they don't exist
  Dir.mkdir(success_dir) unless Dir.exist?(success_dir)
  Dir.mkdir(failed_dir) unless Dir.exist?(failed_dir)

  # MySQL credentials from database.yml
  database_config = YAML.load_file('config/database.yml', aliases: true)[Rails.env]
  username = database_config['username']
  password = database_config['password']
  host = database_config['host']
  port = database_config['port']

  # Array to store commands for loading dumps
  commands = []

  # Loop through each dump file in the directory
  Dir.glob("#{dump_dir}/*.sql.gz") do |file_path|
    # Extract database name from file name
    filename = File.basename(file_path)
    database = filename.split('.').first

    # Check if database already exists
    if ActiveRecord::Base.connection.execute("SHOW DATABASES LIKE '#{database}'").first
      puts "Database '#{database}' already exists. Skipping..."
    end

    # Create command to load data into database
    command = "pv #{file_path} | gunzip | mysql -u#{username} -p#{password} -h#{host} -P #{port} #{database}"
    commands << command
  end

  # Execute commands in parallel
  Parallel.each(commands, in_threads: commands.size, progress: 'Loading databases') do |command|
    puts "Executing command: #{command}"
    file_path = command.split(' ')[1]
    filename = File.basename(file_path)
    if system(command)
      puts "Data loaded successfully."
      # Move file to success directory
      FileUtils.mv(file_path, "#{success_dir}/#{filename}")
    else
      puts "Failed to load data."
      # Move file to failed directory
      FileUtils.mv(file_path, "#{failed_dir}/#{filename}")
    end
  end
end

# Run the method to load dumps into databases
load_dumps_into_databases
