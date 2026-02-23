require 'glimmer-dsl-libui'
require_relative 'views/reports_parser'

class MyApp
  include Glimmer
  def self.start
    ReportsParser.new.launch
  end
end

# Launch the application
MyApp.start if __FILE__ == $PROGRAM_NAME