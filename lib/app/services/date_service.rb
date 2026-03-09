# frozen_string_literal: true
require 'date'

# noinspection RubyDynamicConstAssignment
class DateService

  attr_reader :date

  MONTHS_RU = %w[январь февраль март апрель май июнь
         июль август сентябрь октябрь ноябрь декабрь].freeze

  def initialize
    @date = Date.today
  end

  def date_ru
    @date.strftime('%d.%m.%Y')
  end

  def week
    @date.cweek
  end

  def year
    @date.year
  end

  def month_ru
    MONTHS_RU[@date.month - 1]
  end

end
