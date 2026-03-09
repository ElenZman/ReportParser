# frozen_string_literal: true
require 'yaml'
require 'fileutils'
require_relative '../logger'

class ConfigService
  include AppLogger

  CONFIG_PATH = File.expand_path('../../../config.yml', __dir__)

  def initialize
    logger.info("ConfigService: загрузка конфига из #{CONFIG_PATH}")
    @data = YAML.load_file(CONFIG_PATH)
    logger.debug("ConfigService: конфиг загружен, ключи: #{@data.keys.inspect}")
  rescue => e
    logger.error("ConfigService: не удалось загрузить конфиг: #{e.message}")
    raise
  end

  def output_directory
    base = if Gem.win_platform?
             File.join(Dir.home, 'Desktop')
           else
             Dir.home
           end
    dir = File.join(base, 'Отчеты')
    FileUtils.mkdir_p(dir)
    logger.info("ConfigService: директория вывода — #{dir}")
    dir
  end

  def template_path
    path = File.expand_path(@data.dig('template', 'path'))
    logger.info("ConfigService: путь к шаблону — #{path}")
    logger.warn("ConfigService: файл шаблона не найден: #{path}") unless File.exist?(path)
    path
  end
end