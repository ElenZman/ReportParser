# frozen_string_literal: true
require 'glimmer-dsl-libui'

class ReportsParser
  include Glimmer

  def initialize
    #@parserService = FileParserPresenter.new
    #@presenter.add_observer { update_ui }
  end

  def launch
    window('Парсер отчетов', 600, 200) {
      margined true

      vertical_box {
        padded true

        horizontal_box {
          stretchy false
          padded true

          label('Выберите файл, из которого необходимо сформировать отчет.') {
            stretchy false
          }

          button('Выбрать файл') {
            on_clicked do
              file_path = open_file(filters: {
                filters: {
                  'Documents' => ['doc', 'docx', 'odt']
                }
              })
              if !file_path
                msg_box('Отмена', 'Файл не выбран.')
              end
            end
          }
        }

        vertical_box {
          stretchy false

          label('Введите коды через запятую. Например: 12767634, 8874281, 231236176.') {
            stretchy false
          }

          vertical_box {

            horizontal_box {
              stretchy true
              @code_entry = entry {
                stretchy true
              }
            }

            button('Сгенерировать отчет(ы)') {
              on_clicked do
                # to do
              end
            }
          }
        }
      }
    }.show

  end
end
