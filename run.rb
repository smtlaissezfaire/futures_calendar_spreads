
require 'csv'

SYMBOL = "US"

MONTH_CODES = %w(H M U Z)

MONTH_CODES_TO_MONTHS = {
  "F" => "January",
  "G" => "February",
  "H" => "March",
  "J" => "April",
  "K" => "May",
  "M" => "June",
  "N" => "July",
  "Q" => "August",
  "U" => "September",
  "V" => "October",
  "X" => "November",
  "Z" => "December",
}

def contract_month_digit(long_month_name)
  index = MONTH_CODES_TO_MONTHS.values.index(long_month_name)
  sprintf("%02d", (index + 1))
end

def next_code(year, code)
  val = MONTH_CODES[MONTH_CODES.index(code) + 1]

  if val
    [year, val]
  else
    [year + 1, MONTH_CODES[0]]
  end
end

def contract_year(year)
  year.to_s[2..4]
end

def build_contract_code(symbol, year, month_code)
  "#{symbol}#{contract_year(year)}#{month_code}"
end

def get_line_date(line)
  line[0]
end

def get_line_close(line)
  line[4].to_f
end

# 970714,111.75,111.75,111.75,111.75,1,1
# YYMMDD, Open, High, Low, Close, Volume, Open Interest
#
# OR:
# "Date","Open","High","Low","Close","Volume","OpenInt"
# 05/17/1999,96.68800,96.68800,96.68800,96.68800,1,7060

def normalize_data_line(line)
  if line[0] =~ /(\d{2})\/(\d{2})\/(\d{4})/
    # puts "old line: #{line[0]}"
    line[0] = "#{contract_year($3)}#{$1}#{$2}"
    # puts "new line: #{line[0]}"
  end

  line
end

def normalize_data(lines)
  lines.map do |line|
    normalize_data_line(line)
  end
end

Dir.chdir("./data/us")

files = Dir.glob("*.txt")

years = (1977..2002).to_a

year = years.first
month_code = "Z"

puts ["front_month_contract_code", "back_month_contract_code", "start_date", "end_date", "front_month_start_close", "front_month_end_close", "back_month_start_close", "back_month_end_close", "spread_start", "spread_end", "net"].join(", ")

while true
  maybe_next_year, next_month_code = next_code(year, month_code)

  front_month_contract_code = build_contract_code(SYMBOL, year, month_code)
  back_month_contract_code = build_contract_code(SYMBOL, maybe_next_year, next_month_code)

  front_month_contract_code_file_name = "#{front_month_contract_code}.txt"
  back_month_contract_code_file_name = "#{back_month_contract_code}.txt"

  break unless File.exists?(front_month_contract_code_file_name)
  break unless File.exists?(back_month_contract_code_file_name)

  # 970714,111.75,111.75,111.75,111.75,1,1
  # YYMMDD, Open, High, Low, Close, Volume, Open Interest
  #
  # OR:
  # "Date","Open","High","Low","Close","Volume","OpenInt"
  # 05/17/1999,96.68800,96.68800,96.68800,96.68800,1,7060

  month_code_to_months_keys = MONTH_CODES_TO_MONTHS.keys
  index = month_code_to_months_keys.index(month_code)
  roll_month_name = MONTH_CODES_TO_MONTHS[month_code_to_months_keys[index - 1]]

  front_month_contract_data = CSV.parse(File.read(front_month_contract_code_file_name))
  back_month_contract_data = CSV.parse(File.read(back_month_contract_code_file_name))

  front_month_contract_data = normalize_data(front_month_contract_data)
  back_month_contract_data = normalize_data(back_month_contract_data)

  # exclude lines where one doesn't include the other's dates
  dates1 = front_month_contract_data.map { |line| line[0] }
  dates2 = back_month_contract_data.map { |line| line[0] }

  front_month_contract_data.reject! { |line| !dates2.include?(line[0]) }
  back_month_contract_data.reject! { |line| !dates1.include?(line[0]) }

  front_month_matching_contract_data = front_month_contract_data.select do |line|
    line[0] =~ /#{contract_year(year)}#{contract_month_digit(roll_month_name)}/
  end

  if !front_month_matching_contract_data.any?
    puts "HERE!!"
    puts "#0"
    puts dates1
    puts "------"
    puts dates2
    puts front_month_contract_data
    puts "#1"
    puts front_month_matching_contract_data
    raise "got here"
  end

  front_month_first_day_data = front_month_matching_contract_data.first
  front_month_last_day_data = front_month_matching_contract_data.last

  back_month_first_day_data = back_month_contract_data.detect { |line| line[0] == front_month_first_day_data[0] }
  back_month_last_day_data = back_month_contract_data.detect { |line| line[0] == front_month_last_day_data[0] }

  # puts [front_month_contract_code, back_month_contract_code].join(" - ")
  front_month_start_close = get_line_close(front_month_first_day_data)
  front_month_end_close = get_line_close(front_month_last_day_data)
  # puts back_month_first_day_data
  back_month_start_close = get_line_close(back_month_first_day_data)
  back_month_end_close = get_line_close(back_month_last_day_data)

  spread_start = front_month_start_close - back_month_start_close
  spread_end = front_month_end_close - back_month_end_close
  net = spread_start - spread_end

  start_date = get_line_date(front_month_first_day_data)
  end_date = get_line_date(front_month_last_day_data)

  # puts "SPREAD start date: #{get_line_date(front_month_first_day_data)} (#{spread_start})"
  # puts "SPREAD end date: #{get_line_date(front_month_last_day_data)} (#{spread_end})"
  # puts "NET: #{net}"

  puts [front_month_contract_code, back_month_contract_code, start_date, end_date, front_month_start_close, front_month_end_close, back_month_start_close, back_month_end_close, spread_start, spread_end, net].join(", ")


  year, month_code = maybe_next_year, next_month_code

  # break
end
