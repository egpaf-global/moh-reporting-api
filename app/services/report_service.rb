# frozen_string_literal: true

class ReportService
  ENGINES = {
    'HIV PROGRAM' => ArtService::ReportEngine
  }.freeze
  LOGGER = Rails.logger

  def initialize(program_id:, immediate_mode: false, overwrite_mode: false)
    @program = Program.find(program_id)
    @immediate_mode = immediate_mode
    @overwrite_mode = overwrite_mode
  end

  def generate_report(name:, type:, start_date: Date.strptime('1900-01-01'),
                      end_date: Date.today, **kwargs)
    LOGGER.debug "Retrieving report, #{name}, for period #{start_date} to #{end_date}"
    report = find_report(type, name, start_date, end_date, **kwargs)

    if report && @overwrite_mode
      report.destroy
      report = nil
    end

    return report if report

    LOGGER.debug("#{name} report not found... Queueing one...")
    queue_report(name:, type:, start_date:, end_date:, **kwargs)
    nil
  end

  private

  def engine(program)
    ENGINES[program_name(program)].new
  end

  def program_name(program)
    program.concept.concept_names.each do |concept_name|
      name = concept_name.name.upcase
      return name if ENGINES.include?(name)
    end
  end

  def find_report(type, name, start_date, end_date, **kwargs)
    engine(@program).find_report(type:, name:,
                                 start_date:, end_date:,
                                 **kwargs)
  end

  def queue_report(start_date:, end_date:, **kwargs)
    kwargs[:start_date] = start_date.to_s
    kwargs[:end_date] = end_date.to_s
    kwargs[:user] = User.first.user_id

    LOGGER.debug("Queueing #{kwargs['type']} report: #{kwargs}")
    if @immediate_mode
      ReportJob.perform_now(engine(@program).class.to_s, **kwargs)
    else
      ReportJob.perform_later(engine(@program).class.to_s, **kwargs)
    end
  end
end
