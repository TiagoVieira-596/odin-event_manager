require 'time'
require 'date'
require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers(homephone)
  phone_number = homephone.split('').filter { |digit| digit.ord >= 48 && digit.ord <= 57 }.join('')
  return 'Bad Number' if phone_number.length != 10 || (phone_number.length == 11 && phone_number[0] != '1')

  phone_number.slice!(1..) if phone_number.length == 11
  phone_number
end

def get_time(registration_time)
  Time.strptime(registration_time, '%m/%d/%y %H:%M')
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

attendees_reg_hours = []
attendees_reg_week_days = []
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  time_of_registration = get_time(row[:regdate])
  registration_hour = time_of_registration.hour
  attendees_reg_hours << registration_hour
  registration_week_day = time_of_registration.wday
  attendees_reg_week_days << registration_week_day
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone_number = clean_phone_numbers(row[:homephone])
  p phone_number

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

count = 0
attendees_reg_hours.tally.each_value do |value|
  count = value if value > count
end
p(attendees_reg_hours.tally.filter { |_key, value| value == count })
count = 0
attendees_reg_week_days.tally.each_value do |value|
  count = value if value > count
end
p(attendees_reg_week_days.tally.filter { |_key, value| value == count })
