require 'mysql2'

# Configuration
DESTINATION_DATABASE = "ohdl"
TABLES = ['obs', 'encounter', 'users', 'drug_order', 'orders', 'patient', 'patient_identifier', 'patient_program', 'patient_state', 'person', 'person_address', 'person_attribute', 'person_name', 'pharmacies', 'pharmacy_batch_item_reallocations', 'pharmacy_batch_items', 'pharmacy_batches', 'pharmacy_obs', 'pharmacy_stock_balances', 'pharmacy_stock_verifications', 'relationship']
PARTITIONED_TABLES = ['obs']
SOURCE_CREDENTIALS = { host: 'localhost', username: 'test', password: 'test', database: '', socket: '/var/run/mysqld/mysqld.sock' }
DESTINATION_CREDENTIALS = { host: 'localhost', username: 'test', password: 'test', database: DESTINATION_DATABASE, socket: '/var/run/mysqld/mysqld.sock' }
source_databases = Mysql2::Client.new(SOURCE_CREDENTIALS.merge(database: 'databases')).query('SELECT `database` FROM `databases` WHERE active = 1').map { |db| db['database'] }
POOL_SIZE = 350 # Number of threads in the pool

# Log file path
LOG_FILE_PATH = "error.log"

# Function to fetch site_id from global property table
def fetch_site_id(client, database)
  result = client.query("SELECT property_value FROM global_property WHERE property = 'current_health_center_id'", database: database)
  site_id = result.first['property_value']
  site_id.to_s if site_id # Convert to string only if site_id is not nil
end

# Function to execute upsert query
def execute_upsert_query(client, source_db, table, site_id)
  patitioned = "PARTITION (p#{site_id})"
  query = <<-SQL
    INSERT INTO #{DESTINATION_DATABASE}.#{table} 
    #{patitioned}
    SELECT #{table}.*, '#{site_id}' AS site_id 
    FROM #{source_db}.#{table} 
    ON DUPLICATE KEY UPDATE 
    #{table}.site_id = VALUES(site_id);
  SQL
  client.query(query)
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

# Method to count records in the obs table for a given client
 def count_obs_records(client, database)
   result = client.query("SELECT COUNT(*) AS count FROM #{database}.obs")
   result.first['count']
 end


# Main ETL process
pool = ThreadPool.new(POOL_SIZE)

obs_table_sizes = {}
  source_databases.each do |source_db|
    pool << proc do
      begin
        source_client = Mysql2::Client.new(SOURCE_CREDENTIALS.merge(database: source_db))
        obs_count = count_obs_records(source_client, source_db)
	obs_table_sizes[source_db] = obs_count
      rescue => e
        puts e.message
      ensure
        source_client&.close
      end
    end
end

pool.shutdown

source_databases.sort_by! { |source_db| obs_table_sizes[source_db] || 0 }.reverse!

pool = ThreadPool.new(POOL_SIZE) # Initialize another pool Object

iteration = 0
total_iterations = TABLES.length * source_databases.length

TABLES.each do |table|
  source_databases.each do |source_db|
    pool << proc do
      begin
        site_id = nil
        source_client = Mysql2::Client.new(SOURCE_CREDENTIALS.merge(database: source_db))
        site_id = fetch_site_id(source_client, source_db)
        source_client.close

        if site_id.nil?
          puts "Site ID not found for #{source_db}"
          next
        end

        destination_client = Mysql2::Client.new(DESTINATION_CREDENTIALS)
        execute_upsert_query(destination_client, source_db, table, site_id)
        destination_client.close
      rescue => e
        # Append error message to the log file
        #log_file.puts "Error processing #{table} in #{source_db}: #{e.message}"
        puts "Error processing #{table} in #{source_db}: #{e.message}"
	source_client&.close
	destination_client&.close
      ensure
        iteration += 1
        progress = (iteration.to_f / total_iterations * 100).round(2)
        print "Progress: #{progress}% (#{iteration}/#{total_iterations} threads completed) \r"
      end
    end
  end
end

# Wait for all threads to finish
pool.shutdown
