#!/usr/bin/env ruby

require 'amatch'
require 'open-uri'
require 'mechanize'
require 'highline/import'
require 'optparse'
require 'fileutils'

def download_paper(id, title, dir)
  filename = "#{dir}/#{title}.pdf"
  if File.exist?(filename)
    puts "Skipping paper: File '#{filename}' already exists"
    return
  end

  puts "Downloading paper #{title}"
  url = "http://ijcai.org/Proceedings/16/Papers/%03d.pdf" % id
  begin
    open(url, "rb") do |read_file| # uses open from open-uri
      FileUtils.mkdir_p dir
      File.open(filename, "wb") {|saved_file| saved_file.write(read_file.read) }
    end
  rescue OpenURI::HTTPError
    warn "Could not download #{url}: #{$!}"
  rescue
    warn "Could not write to #{filename}: #{$!}"
  end
end

# Read proceedings to get a list of all titles along with their IDs
def read_proceedings
  @proceedings_papers = []
  title = nil

  File.foreach(open('http://ijcai.org/proceedings/2016')) do |line|
    if title.nil?
      title_match = /^<p>(.*) \/ [0-9]*<br \/>$/.match(line) or next
      title = title_match[1]
      # strip HTML
      title = Nokogiri.HTML(title).xpath('//text()').to_s
    else
      id_match = /^<a href="\/Proceedings\/16\/Papers\/([0-9]+).pdf">.*/.match(line) or next
      @proceedings_papers << [title, id_match[1].to_i]
      title = nil
    end
  end

  @proceedings_titles = @proceedings_papers.transpose.first
end

# Log in to confer and get titles of the liked papers
def login(user, password)
  page = @agent.get('http://confer.csail.mit.edu/login?redirect_url=/ijcai2016/papers')
  page.form.login_email = user
  page.form.login_password = password
  page = page.form.submit
  abort 'Login failed' unless page.search('div#error').empty?
end

def read_likes
  confer_data_json = @agent.get('http://confer.csail.mit.edu/data').body
  @likes = JSON.parse(confer_data_json)['likes']
end

def read_confer_papers
  confer_papers_json = @agent.get('http://confer.csail.mit.edu/static/conf/ijcai2016/data/papers.json').body
  confer_papers_json.slice!(0, 9) # remove "entities=" prefix
  @confer_papers = JSON.parse(confer_papers_json)
end

def download_liked_papers(dir)
  @likes.each do |id|
    paper = @confer_papers[id]
    #next if paper['type'] != 'paper'
    next if paper['abstract'].empty?
    scores = Amatch::LongestSubsequence.new(paper['title']).match(@proceedings_titles)
    closest_paper = @proceedings_papers[scores.each_with_index.max[1]]
    download_paper(closest_paper[1], closest_paper[0], dir)
  end
end

user = nil
password = nil
directory = './papers'

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [-u user] [-p password] [-d paper_directory]"

  opts.on('-h', '--help', 'Print usage information') do
    puts opts
    exit
  end

  opts.on('-u username', 'Confer user name (will prompt if missing)') do |u|
    user = u
  end

  opts.on('-p password', 'Confer password (will prompt if missing)') do |p|
    password = p
  end

  opts.on('-d directory', "Directory where to put papers (default: #{directory})") do |d|
    directory = d
  end
end

optparse.parse!

ARGV.empty? or abort optparse.to_s
user = ask('User: ') if user.nil?
password = ask('Password: ') {|q| q.echo = false} if password.nil?

read_proceedings
@agent = Mechanize.new
@agent.user_agent_alias = 'Linux Firefox'
login(user, password)
read_likes
read_confer_papers
download_liked_papers(directory)
