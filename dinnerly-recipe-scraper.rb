#!/usr/bin/env ruby

require 'webdrivers/chromedriver'
require 'selenium-webdriver'

require_relative 'dinnerly'

options = Selenium::WebDriver::Chrome::Options.new
options.add_preference('download', {
                         'prompt_for_download' => 'false',
                         'default_directory' => "#{__dir__}/recipes_pdf"
                       })
options.add_preference('plugins', {
                         'always_open_pdf_externally' => true
                       })
options.add_argument('--headless')
driver = Selenium::WebDriver.for(:chrome, options: options)
dinnerly = Dinnerly.new(ARGV[0].to_s, ARGV[1].to_s, driver)

puts('Starting...')
case ARGV[2]
when 'pdf'
  puts('Downloading current recipes')
  dinnerly.download_current_recipes_pdf

  puts('Downloading past recipes')
  dinnerly.download_past_recipes_pdf
when 'json'
  puts('Downloading current recipes')
  dinnerly.download_current_recipes_json

  puts('Downloading past recipes')
  dinnerly.download_past_recipes_json
end

puts('Closing...')
sleep 10
driver.quit
