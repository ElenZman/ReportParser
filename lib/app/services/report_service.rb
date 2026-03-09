# frozen_string_literal: true

require 'nokogiri'
require 'zip'
require 'fileutils'
require 'tmpdir'
require_relative 'date_service'
require_relative '../logger'

class ReportService
  include AppLogger

  SYSTEMS_ORDER = %w[АСУТП ОВКВ Электрика КИП].freeze

  # Generate a report docx from parsed entries.
  # If a template_path is provided, tries to preserve its structure.
  #
  # @param entries [Array<ReportEntry>]
  # @param output_dir [String]
  # @param template_path [String, nil] optional template docx to base document on
  def generate(entries, output_dir, template_path: nil)
    logger.info("ReportService: генерация отчёта, записей — #{entries.size}, шаблон — #{template_path}")
    generate_from_template(entries, output_dir, template_path)
  end

  private

  def generate_from_template(entries, output_dir, template_path)
    output_file_name = "004.3 Приложение №4в #{DateService.new.date_ru}"
    output_path = File.join(output_dir, "#{output_file_name}.docx")
    logger.info("ReportService: выходной файл — #{output_path}")

    xml = read_document_xml(template_path)
    logger.debug("ReportService: XML шаблона прочитан, размер — #{xml.length} символов")

    xml = inject_placeholders(xml, entries)

    write_docx(output_path, xml, template_path)
    logger.info("ReportService: файл успешно записан — #{output_path}")
    { success: true, message: "Готово! Файл сохранён: #{output_path}" }
  rescue => e
    logger.error("ReportService: ошибка генерации — #{e.class}: #{e.message}")
    { success: false, message: "Ошибка: #{e.message}" }
  end

  # ── Placeholder replacement ────────────────────────────────────────────

  def inject_placeholders(xml, entries)
    ds = DateService.new

    logger.debug("ReportService: подстановка плейсхолдеров — дата=#{ds.date_ru}, неделя=#{ds.week}, год=#{ds.year}, месяц=#{ds.month_ru}")
    xml = xml.gsub('{{date}}',  ds.date_ru)
    xml = xml.gsub('{{week}}',  ds.week.to_s)
    xml = xml.gsub('{{year}}',  ds.year.to_s)
    xml = xml.gsub('{{month}}', ds.month_ru)
    logger.debug("ReportService: XML после подстановки дат — #{xml.length} символов")

    xml = inject_entries_table(xml, entries)
  end

  # Replaces the paragraph containing {{table}} with a full <w:tbl> element.
  # A simple gsub won't work here because {{table}} sits inside a <w:p>,
  # but we need to insert a <w:tbl> — a sibling of <w:p>, not a child.
  # So we match the entire <w:p>...</w:p> block that contains {{table}}
  # and replace it with the generated table XML.
  def inject_entries_table(xml, grouped)
    logger.debug("ReportService: построение XML таблицы для #{grouped.size} групп")
    table_xml = build_table_xml(grouped)
    result = xml.gsub(/<w:p[ >](?:(?!<\/w:p>).)*{{table}}(?:(?!<\/w:p>).)*<\/w:p>/, table_xml)
    if result == xml
      logger.warn("ReportService: плейсхолдер {{table}} не найден в шаблоне — таблица не вставлена")
    else
      logger.info("ReportService: таблица успешно вставлена в документ")
    end
    result
  end

  # ── Table builder ──────────────────────────────────────────────────────

  def build_table_xml(grouped)
    rows = build_header_row + build_data_rows(grouped)
    <<~XML
      <w:tbl>
        <w:tblPr>
          <w:tblW w:w="9360" w:type="dxa"/>
          <w:tblBorders>
            <w:top    w:val="single" w:sz="4" w:space="0" w:color="000000"/>
            <w:left   w:val="single" w:sz="4" w:space="0" w:color="000000"/>
            <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>
            <w:right  w:val="single" w:sz="4" w:space="0" w:color="000000"/>
            <w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>
            <w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>
          </w:tblBorders>
        </w:tblPr>
        <w:tblGrid>
          <w:gridCol w:w="2000"/>
          <w:gridCol w:w="1500"/>
          <w:gridCol w:w="5860"/>
        </w:tblGrid>
        #{rows}
      </w:tbl>
    XML
  end

  def build_header_row
    cells =   header_cell('Установка', 2000) +
      header_cell('Система',   1500) +
      header_cell('Испытание', 5860)
    wrap_row(cells)
  end


  def build_data_rows(grouped)
    # Handle both array and hash structures
    items = grouped.is_a?(Array) ? grouped : grouped.to_a

    items.flat_map do |item|
      # Extract code and systems from each item
      code = item[:code] || item['code']
      systems = item[:systems] || item['systems']

      # Skip if systems is nil
      next [] if systems.nil?

      SYSTEMS_ORDER.filter_map do |system|
        next unless systems[system]

        # Convert string to array if needed (your data shows strings, not arrays)
        text = systems[system].is_a?(String) ? systems[system] : systems[system].join("\n")

        cells = data_cell(code, 2000, bold: true) +
                data_cell(system, 1500)            +
                data_cell(text, 5860)
        wrap_row(cells)
      end
    end.join
  end

  # ── Cell / row helpers ─────────────────────────────────────────────────

  def wrap_row(cells_xml)
    "<w:tr>#{cells_xml}</w:tr>"
  end

  def header_cell(text, width)
    <<~XML
      <w:tc>
        <w:tcPr>
          <w:tcW w:w="#{width}" w:type="dxa"/>
          <w:shd w:val="clear" w:color="auto" w:fill="D9D9D9"/>
        </w:tcPr>
        <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>#{escape(text)}</w:t></w:r></w:p>
      </w:tc>
    XML
  end

  def data_cell(text, width, bold: false)
    rpr  = bold ? '<w:rPr><w:b/></w:rPr>' : ''
    # Split text on newlines into separate <w:p> paragraphs
    paragraphs = text.to_s.split("\n").map do |line|
      "<w:p><w:r>#{rpr}<w:t xml:space=\"preserve\">#{escape(line)}</w:t></w:r></w:p>"
    end.join
    paragraphs = "<w:p/>" if paragraphs.empty?

    <<~XML
      <w:tc>
        <w:tcPr><w:tcW w:w="#{width}" w:type="dxa"/></w:tcPr>
        #{paragraphs}
      </w:tc>
    XML
  end

  # ── Docx read / write ──────────────────────────────────────────────────

  def read_document_xml(docx_path)
    logger.debug("ReportService: чтение word/document.xml из #{docx_path}")
    Zip::File.open(docx_path) { |zip| zip.read('word/document.xml').force_encoding('UTF-8') }
  rescue => e
    logger.error("ReportService: не удалось прочитать шаблон DOCX: #{e.message}")
    raise
  end

  def write_docx(output_path, new_xml, template_path)
    logger.debug("ReportService: копирование шаблона в #{output_path}")
    FileUtils.cp(template_path, output_path)
    Zip::File.open(output_path) do |zip|
      zip.get_output_stream('word/document.xml') { |f| f.write(new_xml) }
    end
  rescue => e
    logger.error("ReportService: не удалось записать DOCX: #{e.message}")
    raise
  end

  def escape(str)
    str.to_s
       .gsub('&', '&amp;')
       .gsub('<', '&lt;')
       .gsub('>', '&gt;')
  end
end
