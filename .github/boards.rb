require 'csv'
require 'json'
require 'nokogiri'
require 'net/http'

# Generically parse an html table into a CSV table (CSV tables are the best way to represent tabular data in ruby)

# Parse the html page into a Nokogiri document
document = Nokogiri::HTML4(Net::HTTP.get(URI('https://www.chromium.org/chromium-os/developer-library/reference/development/developer-information-for-chrome-os-devices/')))

# Find the last html table in the document (the one we're interested in)
table = document.css('table').last

# Parse the header row (delineated by the <th> tag) into an array
headers = table.css('th').map(&:text)

# Create an empty array
rows = []

# Loop over the remaining table rows (skip the header row to avoid issues)
table.css('tr').drop(1).each do |row|
  # Parse each row into a CSV row and append it to the array
  rows.append(CSV::Row.new(headers, row.css('td').map(&:text)))
end

# Create the CSV table
table = CSV::Table.new(rows)

board_names = {}

table['Board name(s)'].each_with_index do |name, i|
  name = name.downcase.tr('_', '-')
  if name.include?('&')
    board_names[name.split(' & ')[0]] = i
    board_names[name.split(' & ')[1]] = i
    next
  end
  board_names[name] = i
end

json = JSON.parse(Net::HTTP.get(URI('https://chromiumdash.appspot.com/cros/fetch_serving_builds')))

board_names.delete_if { |e| json['builds'][e].nil? }

output_hash = {}

board_names.each do |name, row|
  output_hash[name] = Hash[
    'User ABI': table[row][6],
    'Kernel ABI': table[row][8],
    'Kernel Version': table[row][7],
    'Recovery Images': json['builds'][name].key?('models') ? json['builds'][name]['models'].values[0]['pushRecoveries'] : json['builds'][name]['pushRecoveries']
  ]
end

File.write('boards.json', JSON.pretty_generate(output_hash))
