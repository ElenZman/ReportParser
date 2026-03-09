# frozen_string_literal: true

require 'logger'
require 'fileutils'
require 'date'

module AppLogger
  def logger
    AppLogger.instance
  end

  def self.instance
    @logger ||= begin
      log_file = File.join(log_dir, "лог_ошибок_#{Date.today.strftime('%Y-%m-%d')}.log")
      l = Logger.new(log_file, progname: nil)
      l.level = Logger::DEBUG
      l.formatter = proc do |severity, datetime, _progname, msg|
        "[#{datetime.strftime('%H:%M:%S')}] #{severity.ljust(5)} -- #{msg}\n"
      end
      l
    end
  end

  def self.log_dir
    base = Gem.win_platform? ? File.join(Dir.home, 'Desktop') : Dir.home
    dir  = File.join(base, 'Отчеты')
    FileUtils.mkdir_p(dir)
    dir
  end
end