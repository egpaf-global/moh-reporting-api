# frozen_string_literal: true

# Adding reports
class AddOtherReportsToDef < ActiveRecord::Migration[7.0]
  def change
    # this a hash key, value
    # loop through
    User.current = User.first
    MalawiHivProgramReports::ReportMap::REPORTS.each do |key, value|
      puts "processing #{key} report, found #{value}"
      ReportType.find_or_create_by(name: key, creator: (User.current.user_id rescue 1), date_created: Time.now)
    end
  end
end
