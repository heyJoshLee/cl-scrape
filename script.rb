require 'nokogiri'
require "HTTParty"
require "pry"

class Scraper
  attr_accessor :parse_page, :areas, :categories, :results

  def initialize
    @areas = []
    @categories = []
    @results = []
  end

  def get_areas_list
    doc = HTTParty.get("https://geo.craigslist.org/iso/us")
    @parse_page ||= Nokogiri::HTML(doc)
    list_items = @parse_page.css(".geo-site-list").css("li")
    list_items.each do |item|
      @areas.push({ area_name: item.text, link: item.css("a")[0]["href"] })
    end
  end

  def get_categories(area)
    # get category names and links put in @categories
    # all of the areas should have the same categories
    # so just need to get them from one 
    area_page = HTTParty.get(area[:link])
    area_doc ||= Nokogiri::HTML(area_page)
    # get links on the page and put into array
    area_doc.css("a[href*='/d/']").each do |item| 
      # check if text is a number, if it is, that
      # means it is from the calender and we dont't
      # want those
      is_number = item.text.to_f.to_s == item.text.to_s || item.text.to_i.to_s == item.text.to_s
      if (!is_number)
        @categories << {
          category_name: item.text,
          category_link: item[:href]
        }
      end
    end
  end

  def user_picks_category
    # print list of all of the categories
    @categories.each_with_index { |n, i| puts "#{i} - #{n[:category_name]}"}
    # get user input
    index_for_category = false
    while(!index_for_category) do
      puts "Pick a category"
      index_for_category = gets
      index_for_category = index_for_category.chomp.to_i
      puts "You picked"
      puts @categories[index_for_category][:category_name]
    end
    @categories[index_for_category]
  end

  def go_to_category_pages(category)
    @areas.each do |area|
      puts "Getting data from #{area[:area_name]}"
      url = area[:link] + category[:category_link]
      category_page = HTTParty.get(url)
      category_doc ||= Nokogiri::HTML(category_page)

      # Go through the results on the page and add to @results
      category_doc.css(".result-info").each do |result|
        title = result.css("a")[0].text 
        link = result.css("a")[0][:href]
        date = result.css("time")[0].text 
        @results << {
          title: title,
          link: link,
          date: date
        }
      end
    end
  end

  def write_to_file
    output_file = File.new("output.csv", "w")
    @results.each do |result|
      output_file.puts("#{result[:title]}, #{result[:link]}, #{result[:date]}")
    end
    output_file.close
  end

  def scrape
    get_areas_list
    get_categories(@areas[0])
    go_to_category_pages(user_picks_category)
    write_to_file
  end

end

scraper = Scraper.new
scraper.scrape
