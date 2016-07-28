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
    warn "Skipping paper: File '#{filename}' already exists"
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

# Log in to confer and get titles of the liked papers
def login(agent, user, password)
  page = agent.get('http://confer.csail.mit.edu/login?redirect_url=/ijcai2016/papers')
  page.form.login_email = user
  page.form.login_password = password
  page = page.form.submit
  abort 'Login failed' unless page.search('div#error').empty?
end

# Read proceedings to get a list of all titles along with their IDs
def read_proceedings
  proceedings_papers = []
  title = nil

  File.foreach(open('http://ijcai.org/proceedings/2016')) do |line|
    if title.nil?
      title_match = /^<p>(.*) \/ [0-9]*<br \/>$/.match(line) or next
      title = title_match[1]
      # strip HTML
      title = Nokogiri.HTML(title).xpath('//text()').to_s
    else
      id_match = /^<a href="\/Proceedings\/16\/Papers\/([0-9]+).pdf">.*/.match(line) or next
      proceedings_papers << [title, id_match[1].to_i]
      title = nil
    end
  end

  proceedings_papers
end

def read_confer_papers(agent)
  confer_papers_json = agent.get('http://confer.csail.mit.edu/static/conf/ijcai2016/data/papers.json').body
  confer_papers_json.slice!(0, 9) # remove "entities=" prefix
  JSON.parse(confer_papers_json)
end

def read_likes(agent)
  confer_data_json = agent.get('http://confer.csail.mit.edu/data').body
  JSON.parse(confer_data_json)['likes']
end

def download_liked_papers(likes, confer_papers, proceedings_papers, dir)
  proceedings_titles = proceedings_papers.transpose.first
  likes.each do |id|
    paper = confer_papers[id]
    #next if paper['type'] != 'paper'
    next if paper['abstract'].empty?
    confer_title = paper['title']
    scores = Amatch::LongestSubsequence.new(confer_title).match(proceedings_titles)
    # XXX amatch reports the bytesize (not the length) of the longest common subsequence
    scores.map! {|score| score.to_f / confer_title.bytesize}
    closest_paper = proceedings_papers[scores.each_with_index.max[1]]
    warn "Best match for '#{confer_title}' is not very close." if scores.max < 0.6
    two_best_scores = scores.each_with_index.max(2)
    distance_to_second_best = two_best_scores[0][0] - two_best_scores[1][0]
    if distance_to_second_best < 0.1
      warn "No clearly best matching paper title for '#{confer_title}':"
      warn "1. #{proceedings_titles[two_best_scores[0][1]]}"
      warn "2. #{proceedings_titles[two_best_scores[1][1]]}"
      warn 'Choosing the first one.'
    end
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

agent = Mechanize.new
agent.user_agent_alias = 'Linux Firefox'

proceedings_papers = read_proceedings
login(agent, user, password)
likes = read_likes(agent)
confer_papers = read_confer_papers(agent)
download_liked_papers(likes, confer_papers, proceedings_papers, directory)
