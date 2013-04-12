#!/usr/bin/env ruby
# coding: utf-8

##############
## REQUIRES ##
##############

require 'colorize'
require 'net/http'
require 'mechanize'
require 'ruby-progressbar'

##########
## MAIN ##
##########

def main
  # Usage.
  abort "#{$0} <initial_book_id> <max_downloads> <download_dir>" if ARGV.size != 3

  # Params.
  initial_book_id = ARGV[0].to_i
  max_downloads = ARGV[1].to_i
  download_dir = File.expand_path(ARGV[2])

  # Check.
  abort "Download dir not found: #{download_dir}" unless File.directory?(download_dir)

  # Loop.
  download_counter = 1
  while download_counter <= max_downloads do
    process_book(initial_book_id, download_counter, max_downloads, download_dir)
    initial_book_id += 1
    download_counter += 1
  end
end

# Parse and download.
def process_book(id, download_counter, max_downloads, download_dir)
  domain = 'www.it-ebooks.info'
  ua = 'Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:19.0) Gecko/20100101 Firefox/19.0'

  puts "* (#{download_counter}/#{max_downloads}) Processing book_id: #{id}".light_blue

  # Agent.
  a = Mechanize.new do |agent|
    agent.user_agent = ua
  end

  a.get("http://#{domain}/book/#{id}/") do |page|
    author = page.parser.xpath('//td/b[@itemprop="author"]').children.to_s
    title = page.parser.xpath('//h1').children.to_s
    publisher = page.parser.xpath('//td/b/a[@itemprop="publisher"]').children.to_s
    date = page.parser.xpath('//td/b[@itemprop="datePublished"]').children.to_s
    pages = page.parser.xpath('//td/b[@itemprop="numberOfPages"]').children.to_s
    lang = page.parser.xpath('//td/b[@itemprop="inLanguage"]').children.to_s.downcase
    isbn = page.parser.xpath('//td/b[@itemprop="isbn"]').children.to_s
    format = page.parser.xpath('//td/b[@itemprop="bookFormat"]').children.to_s.downcase
    size = page.parser.xpath('//tr[8]/td[2]/b').children.to_s

    # Filename filter.
    filename = "#{author} - #{title} - #{publisher} - #{date} - #{pages}p - #{lang} - ISBN #{isbn}.#{format}"
    filename = filename.chars.select { |char| char.valid_encoding? }.join
    filename.gsub!(' ', '_')
    filename.gsub!('_+', '_')
    filename.chomp!

    filename_path = "#{download_dir}/#{filename}"
    filename_part_path = "#{filename_path}.part"

    download_link = page.link_with(:id => 'dl')

    if File.exist?(filename_path)
      puts "- Already downloaded (#{id} / #{size}): #{filename}".light_yellow
    else
      if File.exist?(filename_part_path)
        puts "+ Resuming download (#{id} / #{size}): #{filename}".light_green
        filename_part_size = File.stat(filename_part_path).size
        request_headers = {'User-Agent' => ua, 'Range' => "bytes=#{filename_part_size}-"}
      else
        puts "+ Downloading (#{id} / #{size}): #{filename}".light_green
        filename_part_size = 0
        request_headers = {'User-Agent' => ua}
      end

      counter = filename_part_size

      Net::HTTP.start(domain) do |http|
        # No Range here, we want to know the total Content-Length.
        response = http.request_head(URI.escape(download_link.href), {'User-Agent' => ua})

        pbar = ProgressBar.create(:starting_at  => filename_part_size,
                                  :total        => response['Content-Length'].to_i,
                                  :format       => '%a %B %p%% %c/%C %e')

        File.open(filename_part_path, 'ab') do |file|
          http.request_get(URI.escape(download_link.href), request_headers) do |response|
            if response.code == 200
              counter = 0
              file.truncate(0)
            end

            response.read_body do |stream|
              file.write stream
              counter += stream.length
              pbar.progress = counter
            end
          end
        end

        File.rename("#{filename_path}.part", filename_path)
      end
    end
  end
end

begin
  main
rescue Interrupt
  puts
  puts 'Exiting.'
  exit 0
end

=begin
<tr><td width="150">Publisher:</td><td><b><a href="/publisher/3/" title="O'Reilly Media eBooks" itemprop="publisher">O'Reilly Media</a></b></td></tr>
<tr><td>By:</td><td><b itemprop="author" style="display:none;">Cricket Liu</b><b><a href='/author/327/' title='Cricket Liu'>Cricket Liu</a></b></td></tr>
<tr><td>ISBN:</td><td><b itemprop="isbn">978-1-4493-0519-2</b></td></tr>
<tr><td>Year:</td><td><b itemprop="datePublished">2011</b></td></tr>
<tr><td>Pages:</td><td><b itemprop="numberOfPages">52</b></td></tr>
<tr><td>Language:</td><td><b itemprop="inLanguage">English</b></td></tr>
<tr><td>File size:</td><td><b>0.7 MB</b></td></tr>
<tr><td>File format:</td><td><b itemprop="bookFormat">PDF</b></td></tr>
<tr><td colspan="2"><h4>eBook</h4></td></tr>
<tr><td>Download:</td><td>
<a id="dl" href="/go.php?id=433-1365152009-ccad9a79ffff872d665d5e3b27c9e9ce" rel="nofollow">Free</a>    <script>$("#dl").text("DNS and BIND on IPv6")</script>
=end
