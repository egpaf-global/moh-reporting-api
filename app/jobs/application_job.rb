# frozen_string_literal: true

# Application Job
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
  def login(user_id, location_id)
    User.current = User.find(user_id)
    Location.current = Location.find(location_id)
  end
end
