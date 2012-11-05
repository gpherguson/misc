#!/usr/bin/ruby -wKU

require 'jcode'

require 'rubygems'
require 'sequel'
require 'logger'
require 'nokogiri'
require 'open-uri'
require 'set'
require 'uri'

# Show debug output from Sequel as it talks to the DB?
TESTING = true

# Use random sleep times?
USE_SLEEP = true

# Attempt to drop then recreate the DB?
MIGRATE = false

# The base URL for the site.
SITE = 'http://www.sportsshooter.com'

# The starting page for a member.
START_PAGE = "#{ SITE }/member_index.html"

# The feedback page for a member.
FEEDBACK_PAGE = "/instant_feedback.html?"

# Get the URLs for member pages from the primary index pages.
#
# +page+ is the Nokogiri::HTML::Document.
def get_page_urls(page)
  anchors = []
  for _a in page.xpath('.//a[@href]')
    next if (_a['href'].nil? || _a['href'].empty?)
    uri = URI.parse(_a['href'])
    if (uri.query)
      query = Hash[*uri.query.split('&').map{ |_q| a,b = _q.split('='); [a, b || nil] }.flatten]
      anchors << uri if ((uri.path =~ /member_index/) && (query['sort'] == nil) && (query['s'].to_i > 0))
    end
  end
  anchors.map{ |_a| URI::join(SITE, _a.to_s) }.uniq
end

# Get the member page (relative) URL path and member name.
#
# +page+ is the Nokogiri::HTML::Document.
def get_names_and_urls(page)
  names_and_urls = []
  for _a in page.xpath('.//a[@href]')
    names_and_urls << _a if ((_a['href'] =~ %r{^/\w+/$}))
  end
  names_and_urls.map{ |_a| [ _a['href'], _a.content.strip ] }
end

# Get how long the person has been a member and the last time they updated
# from the member's page.
#
# +page+ is the Nokogiri::HTML::Document.
#
# +text+ is the content of the previous sibling's span.
def get_member_page_info(page, text)
  page.css('span').select{ |_span| _span.content[text] }.last
end

# Get the various feedback types from the member and to the member's posts.
#
# +table+ is the Nokogiri::HTML::Node for the table.
#
# +feedback_type+ is the particular type such as "Informative", "Funny", etc.
def get_feedback_type(table, feedback_type)
  table.css('td').select{ |_td| _td.content[feedback_type] }.last.parent.css('td').last.content.scan(/\d+/)
end

# Get the feedback to/from the member.
#
# +page+ is the Nokogiri::HTML::Document for the page.
#
# +to_or_from+ is the text from the parent's previous sibling table being used
# as a marker for this table.
def get_feedback(page, to_or_from)
  table = page.css('table').select{ |_table| _table.content[to_or_from] }.last.next

  feedback = {}
  feedback[ :informative   ] = get_feedback_type(table, 'Informative'  )
  feedback[ :funny         ] = get_feedback_type(table, 'Funny'        )
  feedback[ :huh_eh        ] = get_feedback_type(table, 'Huh?'         )
  feedback[ :off_topic     ] = get_feedback_type(table, 'Off Topic'    )
  feedback[ :inappropriate ] = get_feedback_type(table, 'Inappropriate')

  feedback
end

# Get the number of messages they've posted and the number of threads they've
# participated in.
#
# +feedback_page+ is the Nokogiri::HTML::Document for the page.
#
# +text+ is the text we're searching for in the preceeding table cell.
def get_feedback_threads(feedback_page, text)
  feedback_page.css('td').select{ |td| td.content[text] }.last.parent.css('td').last.content[/\d+$/]
end

# Sequel.connect(
#   :adapter  => 'postgres',
#   :database => 'ssstats',
#   :host     => 'localhost',
#   :username => 'postgres',
#   :password => 'password'
# )
DB = Sequel.sqlite('./SS.db')

TESTING and DB.loggers << Logger.new(STDOUT)

if (MIGRATE)
  begin
    DB.drop_table(:ss_members)
  rescue => e
  ensure
    DB.create_table :ss_members do

      primary_key :id
      Integer :member_id, :key => true, :unique => true
      String :name
      String :url, :length => 128

      Date    :member_since
      Date    :last_update
      Integer :threads_in
      Integer :messages_posted

      Integer :feedback_to_informative
      Integer :feedback_to_funny
      Integer :feedback_to_huh
      Integer :feedback_to_off_topic
      Integer :feedback_to_inappropriate

      Float   :feedback_to_informative_percentage
      Float   :feedback_to_funny_percentage
      Float   :feedback_to_huh_percentage
      Float   :feedback_to_off_topic_percentage
      Float   :feedback_to_inappropriate_percentage

      Integer :feedback_by_informative
      Integer :feedback_by_funny
      Integer :feedback_by_huh
      Integer :feedback_by_off_topic
      Integer :feedback_by_inappropriate

      Float   :feedback_by_informative_percentage
      Float   :feedback_by_funny_percentage
      Float   :feedback_by_huh_percentage
      Float   :feedback_by_off_topic_percentage
      Float   :feedback_by_inappropriate_percentage

      DateTime :updated_on
    end
  end
end

class Member < Sequel::Model(:ss_members)
end

puts "Gathering members..."
members = {}
for _page_url in get_page_urls(Nokogiri::HTML(open(START_PAGE))).flatten
  print _page_url, "\r"
  members.merge!(Hash[*get_names_and_urls(Nokogiri::HTML(open(_page_url))).flatten])

  USE_SLEEP and sleep 2 + rand(5)
end

puts
puts "Walking members..."
members.each_pair do |_k, _v|

  puts "Checking #{ _v } (#{ SITE + _k })"

  # Make a connection to the site...
  stream = open(SITE + _k)

  # ...read the page...
  body = stream.read

  # ...the connection got redirected so grab the final URL...
  base_uri = URI.parse(stream.base_uri.to_s)

  # ... and create a URL for the feedback page we'll want to read.
  feedback_url = base_uri.merge(FEEDBACK_PAGE + base_uri.query).to_s

  # Grab the member ID because it will make a good index.
  member_id = base_uri.query.split('=').last

  # Read the member's page and get the last time they updated and how long
  # they've been a member...
  member_page = Nokogiri::HTML(body)

  # The data we want is stored in separate pages, and in separate tables on the
  # member's page, so we'll group it into hashes representing those divisions.
  member_page_info = {}
  member_page_info[ :last_update  ] = get_member_page_info(member_page, 'days ago'    ).content[/(\d+)/, 1] rescue 0
  member_page_info[ :member_since ] = get_member_page_info(member_page, 'Member Since').parent.parent.css('span').last.content[/\d+\.\d+\.\d+/].gsub('.', '/') rescue Date.today.to_s

  # Read the feedback page and get the number of messages they have participated
  # in and have posted.
  feedback_page = Nokogiri::HTML(open(feedback_url))

  messages_by = {}
  messages_by[ :threads_participating_in ] = get_feedback_threads(feedback_page, 'Threads Participating In')
  messages_by[ :messages_posted          ] = get_feedback_threads(feedback_page, 'Messages Posted'         )

  # Read the feedback they've been given by other people...
  # 
  # The value for each key is an array and we're grabbing two values, so append
  # them, don't assign them.
  feedback_to = get_feedback(feedback_page, 'made to')

  # Read the feedback they've given other people...
  # 
  # The value for each key is an array and we're grabbing two values, so append
  # them, don't assign them.
  feedback_by = get_feedback(feedback_page, 'made by')

  # Check the database. If there is a record for them update it, otherwise
  # create a new one...
  if (ss_member = Member.first(:member_id => member_id))
    ss_member.update(
      :member_since => member_page_info[:member_since],
      :last_update  => (Date.today - member_page_info[:last_update].to_i).to_s,

      :threads_in      => messages_by[ :threads_participating_in ].to_i,
      :messages_posted => messages_by[ :messages_posted          ].to_i,

      :feedback_to_informative_percentage   => feedback_to[ :informative   ].first,
      :feedback_to_funny_percentage         => feedback_to[ :funny         ].first,
      :feedback_to_huh_percentage           => feedback_to[ :huh_eh        ].first,
      :feedback_to_off_topic_percentage     => feedback_to[ :off_topic     ].first,
      :feedback_to_inappropriate_percentage => feedback_to[ :inappropriate ].first,

      :feedback_to_informative              => feedback_to[ :informative   ].last,
      :feedback_to_funny                    => feedback_to[ :funny         ].last,
      :feedback_to_huh                      => feedback_to[ :huh_eh        ].last,
      :feedback_to_off_topic                => feedback_to[ :off_topic     ].last,
      :feedback_to_inappropriate            => feedback_to[ :inappropriate ].last,

      :feedback_by_informative_percentage   => feedback_by[ :informative   ].first,
      :feedback_by_funny_percentage         => feedback_by[ :funny         ].first,
      :feedback_by_huh_percentage           => feedback_by[ :huh_eh        ].first,
      :feedback_by_off_topic_percentage     => feedback_by[ :off_topic     ].first,
      :feedback_by_inappropriate_percentage => feedback_by[ :inappropriate ].first,

      :feedback_by_informative              => feedback_by[ :informative   ].last,
      :feedback_by_funny                    => feedback_by[ :funny         ].last,
      :feedback_by_huh                      => feedback_by[ :huh_eh        ].last,
      :feedback_by_off_topic                => feedback_by[ :off_topic     ].last,
      :feedback_by_inappropriate            => feedback_by[ :inappropriate ].last
    )
    puts "Updated #{ _v }"
  else
    Member.create(
      :member_id => member_id,
      :url       => SITE + _k,
      :name      => _v,

      :member_since => member_page_info[:member_since],
      :last_update  => (Date.today - member_page_info[:last_update].to_i).to_s,

      :threads_in      => messages_by[ :threads_participating_in ].to_i,
      :messages_posted => messages_by[ :messages_posted          ].to_i,

      :feedback_to_informative_percentage   => feedback_to[ :informative   ].first,
      :feedback_to_funny_percentage         => feedback_to[ :funny         ].first,
      :feedback_to_huh_percentage           => feedback_to[ :huh_eh        ].first,
      :feedback_to_off_topic_percentage     => feedback_to[ :off_topic     ].first,
      :feedback_to_inappropriate_percentage => feedback_to[ :inappropriate ].first,

      :feedback_to_informative              => feedback_to[ :informative   ].last,
      :feedback_to_funny                    => feedback_to[ :funny         ].last,
      :feedback_to_huh                      => feedback_to[ :huh_eh        ].last,
      :feedback_to_off_topic                => feedback_to[ :off_topic     ].last,
      :feedback_to_inappropriate            => feedback_to[ :inappropriate ].last,

      :feedback_by_informative_percentage   => feedback_by[ :informative   ].first,
      :feedback_by_funny_percentage         => feedback_by[ :funny         ].first,
      :feedback_by_huh_percentage           => feedback_by[ :huh_eh        ].first,
      :feedback_by_off_topic_percentage     => feedback_by[ :off_topic     ].first,
      :feedback_by_inappropriate_percentage => feedback_by[ :inappropriate ].first,

      :feedback_by_informative              => feedback_by[ :informative   ].last,
      :feedback_by_funny                    => feedback_by[ :funny         ].last,
      :feedback_by_huh                      => feedback_by[ :huh_eh        ].last,
      :feedback_by_off_topic                => feedback_by[ :off_topic     ].last,
      :feedback_by_inappropriate            => feedback_by[ :inappropriate ].last
    )
    puts "Created #{ _v }"
  end

  if (USE_SLEEP)
    sleep_time = 5 + rand(5)
    puts "...sleeping #{ sleep_time } seconds..."
    sleep sleep_time
  end

end
