# frozen_string_literal: true

require 'docx'
require_relative '../logger'

class ParserService
  include AppLogger

  SYSTEMS      = %w[АСУТП КИП ОВКВ Электрика].freeze
  SYSTEM_ORDER = %w[ОВКВ АСУТП КИП Электрика].freeze
  CODE_PATTERN = /^\d+\.\d+\.\d+\.\d+/

  def initialize(file_path)
    @file_path = file_path
    logger.info("ParserService: инициализация, файл — #{file_path}")
  end

  # Returns grouped result:
  # [{ code: "3.1.1.13.803", systems: { "КИП" => "1. Текст\n2. Текст", ... } }, ...]
  def parse
    logger.info("ParserService: начало парсинга")
    rows   = extract_rows
    logger.info("ParserService: извлечено строк — #{rows.size}")

    blocks = rows_to_blocks(rows)
    logger.info("ParserService: сформировано блоков — #{blocks.size}")

    result = group_by_code_and_system(blocks)
    logger.info("ParserService: итого групп (уникальных кодов) — #{result.size}")
    result
  end

  def filter_by_codes(parsed_result, codes_input)
    return parsed_result if codes_input.nil? || codes_input.strip.empty?

    requested = codes_input.split(/[,;\s]+/).map(&:strip).reject(&:empty?)
    return parsed_result if requested.empty?

    logger.info("ParserService: фильтрация по кодам — #{requested.inspect}")
    filtered = parsed_result.select do |entry|
      requested.any? { |req| entry[:code].start_with?(req) || req.start_with?(entry[:code]) }
    end
    logger.info("ParserService: после фильтрации — #{filtered.size} из #{parsed_result.size}")
    filtered
  end

  private

  # ── Step 1: extract flat list of { row:, text: } hashes from all tables ─

  def extract_rows
    logger.debug("ParserService: открытие файла #{@file_path}")
    doc = Docx::Document.open(@file_path)
    logger.debug("ParserService: таблиц в документе — #{doc.tables.size}")
    doc.tables.flat_map do |table|
      table.rows.map.with_index do |row, idx|
        text = row.cells.map { |c| cell_text(c) }.reject(&:empty?).join(' ').strip
        { row: idx + 1, text: text }
      end
    end.reject { |r| r[:text].empty? }
  rescue => e
    logger.error("ParserService: ошибка при чтении DOCX: #{e.message}")
    raise
  end

  def cell_text(cell)
    text = cell.respond_to?(:paragraphs) ?
             cell.paragraphs.map { |p| p.text.to_s.strip }.reject(&:empty?).join("\n") :
             cell.text.to_s.strip
    text.encode('UTF-8', invalid: :replace, undef: :replace)
  end

  # ── Step 2: convert rows into flat blocks { code:, system:, text: } ─────

  def rows_to_blocks(rows)
    blocks         = []
    current_codes  = []
    current_system = nil

    rows.each do |row|
      text = row[:text]

      next if row[:row] == 1  # skip document-level header rows

      if text.match?(CODE_PATTERN)
        current_codes  = text.split(';').map(&:strip)
        current_system = nil
        logger.debug("ParserService: найден код(ы) — #{current_codes.inspect}")
        next
      end

      if SYSTEMS.include?(text)
        current_system = text
        logger.debug("ParserService: найдена система — #{current_system}")
        next
      end

      next if executor_line?(text)
      next unless current_codes.any? && current_system

      split_work_items(text).each do |item|
        current_codes.each { |code| blocks << { code: code, system: current_system, text: item } }
      end
    end

    blocks
  end

  # Heuristic: looks like "Фамилия И.О." — handles multiple names too
  def executor_line?(text)
    text.match?(/^[А-ЯЁ][а-яё]+\s+[А-ЯЁ]\./) && !text.match?(/^\d/)
  end

  # Split "1. Abc 2. Def" → ["1. Abc", "2. Def"], falls back to [text]
  def split_work_items(text)
    parts = text.split(/(?=\d+\.\s)/).map(&:strip).reject(&:empty?)
    parts.empty? ? [text] : parts
  end

  # ── Step 3: group → [{ code:, systems: { name => joined_text } }] ────────

  def group_by_code_and_system(blocks)
    grouped = blocks.each_with_object({}) do |block, acc|
      (acc[block[:code]] ||= {})[block[:system]] ||= []
      acc[block[:code]][block[:system]] << block[:text]
    end

    grouped.map do |code, systems|
      ordered = SYSTEM_ORDER.each_with_object({}) do |name, h|
        h[name] = systems[name].join("\n") if systems[name]
      end
      { code: code, systems: ordered }
    end
  end
end
