require 'mysql2'

# Configuration
DESTINATION_DATABASE = "ohdl"
TABLES = ['obs', 'encounter', 'users', 'drug_order', 'orders', 'patient', 'patient_identifier', 
'patient_program', 'patient_state', 'person', 'person_address', 'person_attribute', 'person_name', 'relationship',
'pharmacies', 'pharmacy_batch_item_reallocations', 'pharmacy_batch_items', 'pharmacy_batches', 'pharmacy_obs', 
'pharmacy_stock_balances', 'pharmacy_stock_verifications']
SOURCE_CREDENTIALS = { host: 'localhost', username: 'patrick', password: 'passpass', database: '', socket: '/var/run/mysqld/mysqld.sock' }
DESTINATION_CREDENTIALS = { host: 'localhost', username: 'patrick', password: 'passpass', database: DESTINATION_DATABASE, socket: '/var/run/mysqld/mysqld.sock' }

# Thread pool size
POOL_SIZE = 350

# Method to establish MySQL connection
def connect_to_mysql(credentials)
  Mysql2::Client.new(credentials)
end

# Custom thread pool class
class ThreadPool
  def initialize(size)
    @size = size
    @queue = Queue.new
    @threads = []
    @size.times do
      @threads << Thread.new do
        loop do
          task = @queue.pop
          break if task.nil?

          task.call
        end
      end
    end
  end

  def <<(task)
    @queue << task
  end

  def shutdown
    @size.times { @queue << nil }
    @threads.each(&:join)
  end
end

# Connect to source databases
source_databases_client = connect_to_mysql(SOURCE_CREDENTIALS.merge(database: 'databases'))
source_databases = source_databases_client.query('SELECT site_id, `database` FROM `databases` where active = 1')

# Array to hold threads
threads = []
total_databases = source_databases.count
databases_reconciled = 0
successful_reconciliations = 0

pool = ThreadPool.new(POOL_SIZE)

# Hash to track non-matched tables
non_matched_tables = Hash.new(0)

source_databases.each do |source_database|
  # Create a new MySQL connection for each source database
  source_client = connect_to_mysql(SOURCE_CREDENTIALS.merge(database: source_database['database']))
  # Create a new MySQL connection for the destination database
  destination_client = connect_to_mysql(DESTINATION_CREDENTIALS)

  pool << proc do
    all_tables_match = true  # Flag to track if all tables match

    TABLES.each do |table_name|
      begin
        # Get record count from source database
        source_count_query = "SELECT COUNT(*) AS count FROM #{source_database['database']}.#{table_name}"
        source_count_result = source_client.query(source_count_query).first
        source_count = source_count_result['count']

        # Get record count from destination database
        destination_count_query = "SELECT COUNT(*) AS count FROM #{DESTINATION_DATABASE}.#{table_name} PARTITION(p#{source_database['site_id']})"
        destination_count_result = destination_client.query(destination_count_query).first
        destination_count = destination_count_result['count']

        # Reconciliation
        if source_count != destination_count
          all_tables_match = false  # Set flag to false if there's a mismatch
          non_matched_tables[table_name] += 1
        end
      rescue Mysql2::Error => e
        puts "Error: #{e.message}"  # Output error message
        all_tables_match = false  # Set flag to false in case of error
      end
    end

    # Check if all tables match for the current database
    if all_tables_match
      # Update 'active' field to 0 for the current database
      update_query = "UPDATE `databases`.`databases` SET active = 0, etl_status = 'ok', updated_at = NOW() WHERE site_id = #{source_database['site_id']}"
      destination_client.query(update_query)
      successful_reconciliations += 1
    end

    source_client.close  # Close the MySQL connection for the source database
    destination_client.close  # Close the MySQL connection for the destination database

    databases_reconciled += 1
    progress = (databases_reconciled.to_f / total_databases) * 100
    print "Progress: #{progress.round(2)}% (#{databases_reconciled}/#{total_databases} databases reconciled) \r"

    if databases_reconciled == total_databases
      puts "\n\nReconciliation Summary:"
      puts "Total databases reconciled: #{total_databases}"
      puts "Successful reconciliations: #{successful_reconciliations}"
      puts "Failed reconciliations: #{total_databases - successful_reconciliations}"
      puts "\nNon-matched Tables Summary:"
      non_matched_tables.each do |table_name, count|
        puts "#{table_name}: #{count}"
      end
    end
  end
end

# Join all threads to wait for them to finish
pool.shutdown
