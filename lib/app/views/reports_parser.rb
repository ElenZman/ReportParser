require 'glimmer-dsl-libui'
require_relative '../services/parser_service'
require_relative '../services/report_service'
require_relative '../services/config_service'
require_relative '../logger'


class ReportsParser
  include Glimmer
  include AppLogger

  attr_accessor :file_path, :config

  def initialize
    @config = ConfigService.new
  end

  def file_label
    if @file_path.nil? || @file_path.empty?
      'Вы выбрали файл:'
    else
      filename = File.basename(@file_path)

      # Try Windows-1251 (common for Russian Windows)
      filename = filename.force_encoding('Windows-1251')
      if filename.valid_encoding?
        filename = filename.encode('UTF-8')
      else
        # Fallback to UTF-8 with replacement
        filename = filename.force_encoding('UTF-8')
        filename = filename.encode('UTF-8', invalid: :replace, undef: :replace) unless filename.valid_encoding?
      end

      "Вы выбрали файл: #{filename}"
    end
  end

  def launch
    window('Парсер отчетов', 700, 200) {
      margined true

      vertical_box {
        padded true

        label("Выберите файл, из которого необходимо сформировать отчет.") {
          stretchy false
        }

        label(' ') { stretchy false }

        horizontal_box {
          padded true

          button('Выбрать файл') {
            on_clicked do
              selected = open_file
              selected = selected.force_encoding('UTF-8') if selected

              if selected.nil?
                logger.info("ReportsParser: выбор файла отменён")
                msg_box('Отмена', 'Файл не выбран.')
              else
                logger.info("ReportsParser: выбран файл — #{selected}")
                self.file_path = selected
              end
            end
          }

          label(' ') { stretchy false }

          label {
            stretchy true
            text <= [self, :file_label, computed_by: [:file_path]]
          }
        }

        # spacer
        label(' ') { stretchy false }

        horizontal_box {
          stretchy false

          button('Сгенерировать отчет(ы)') {
            on_clicked do
              if @file_path.nil?
                logger.warn("ReportsParser: попытка генерации без выбранного файла")
              else
                logger.info("ReportsParser: запуск генерации для файла — #{@file_path}")
                parser_service = ParserService.new(@file_path)
                entries = parser_service.parse
                logger.info("ReportsParser: парсинг завершён, записей — #{entries.size}")
                result = generate_report(entries)
                logger.info("ReportsParser: результат генерации — success=#{result[:success]}, #{result[:message]}")
                #msg_box(result[:message])
              end
            end
          }
        }
      }
    }.show
  end

  def generate_report(entries)
    output_directory  = get_output_directory
    template_path = get_template_path

    report_generator_service = ReportService.new
    result = report_generator_service.generate(entries, output_directory,  template_path: template_path)
    puts result
  end

  def get_output_directory
    @config.output_directory
  end

  def get_template_path
    @config.template_path
  end
end