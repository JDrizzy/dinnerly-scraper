require 'net/http'

class Dinnerly
  URL = 'https://dinnerly.com.au'.freeze

  API_URL = 'https://api.dinnerly.com'.freeze

  WAIT_TIME = 5 # Prevent 429 HTTP code

  def initialize(username, password, driver)
    @username = username
    @password = password
    @driver = driver
    @wait = Selenium::WebDriver::Wait.new(timeout: 20)
  end

  def download_current_recipes_pdf
    login
    select_order_type('Current orders')
    recipes('current-recipe__title') do |recipe_title|
      download_recipe(recipe_title, 'current-recipe__title')
    end
  end

  def download_past_recipes_pdf
    login
    select_order_type('Past orders')
    load_all_past_orders
    recipes('past-recipe__title') do |recipe_title|
      download_recipe(recipe_title, 'past-recipe__title')
    end
  end

  def download_current_recipes_json
    login
    uri = URI.parse("#{API_URL}/users/#{@user_id}/orders/current?brand=dn&country=#{@country}&product_type=web")
    request = Net::HTTP.new(uri.host, uri.port)
    request.use_ssl = true
    response = request.get(uri.request_uri, { 'Authorization' => "Bearer #{@api_token}" })
    JSON.parse(response.body).each do |order|
      order['recipes'].each do |recipe|
        download_recipe_json(recipe['id'])
        sleep(WAIT_TIME)
      end
    end
  end

  def download_past_recipes_json
    login
    uri = URI.parse("#{API_URL}/users/#{@user_id}/orders/past?brand=dn&country=#{@country}&product_type=web&per_page=1000")
    request = Net::HTTP.new(uri.host, uri.port)
    request.use_ssl = true
    response = request.get(uri.request_uri, { 'Authorization' => "Bearer #{@api_token}" })
    JSON.parse(response.body)['data'].each do |order|
      order['recipes'].each do |recipe|
        download_recipe_json(recipe['id'])
        sleep(WAIT_TIME)
      end
    end
  end

  private

  def download_recipe_json(recipe_id)
    uri = URI.parse("#{API_URL}/recipes/#{recipe_id}?brand=dn&country=#{@country}&product_type=web")
    request = Net::HTTP.new(uri.host, uri.port)
    request.use_ssl = true
    response = request.get(uri.request_uri, { 'Authorization' => "Bearer #{@api_token}" })
    Dir.mkdir("#{__dir__}/recipes_json") unless File.exist?("#{__dir__}/recipes_json")
    File.open("#{__dir__}/recipes_json/#{recipe_id}.json", 'w') { |f| f.write(response.body) }
  end

  def login
    @driver.navigate.to("#{URL}/login")
    @driver.find_element(id: 'login_email').send_keys(@username)
    @driver.find_element(id: 'password').send_keys(@password)
    @driver.find_element(id: 'submit').click
    @wait.until { @driver.find_element(:xpath, "//a[contains(text(), 'Logout')]") }
    @api_token = @driver.execute_script('return window.gon.api_token')
    @user_id = @driver.execute_script('return window.gon.current_user_id')
    @country = @driver.execute_script('return window.gon.current_country')
  rescue Selenium::WebDriver::Error::NoSuchElementError
    nil # Already logged in
  end

  def select_order_type(order_type)
    @wait.until { @driver.find_element(:xpath, "//*[contains(text(), '#{order_type}')]") }
    @driver.find_element(:xpath, "//*[contains(text(), '#{order_type}')]").click
    @wait.until { @driver.find_element(:xpath, "//*[contains(text(), 'View recipe card')]") }
  end

  def recipes(recipe_title_class, &block)
    recipe_titles = @driver.find_elements(:xpath, "//div[contains(@class, '#{recipe_title_class}')]").map(&:text)
    recipe_titles.each(&block)
  end

  def download_recipe(recipe_title, recipe_title_class)
    sleep(WAIT_TIME)
    click_element(@driver.find_element(:xpath,
                                       "//div[contains(@class, '#{recipe_title_class}')][contains(text(), \"#{recipe_title}\")]"))
    @wait.until { @driver.find_element(:xpath, "//a[contains(text(), 'Click for printable recipe card')]") }
    @driver.find_element(:xpath, "//a[contains(text(), 'Click for printable recipe card')]").click
    @driver.find_element(:xpath, "//span[contains(@class, 'modal__close-button')]").click
  rescue Selenium::WebDriver::Error::ElementNotInteractableError
    retry
  end

  def load_all_past_orders
    loop do
      click_element(@driver.find_element(:xpath, "//*[contains(text(), 'Load more')]"))
      sleep(WAIT_TIME)
    rescue Selenium::WebDriver::Error::NoSuchElementError
      break
    rescue Selenium::WebDriver::Error::ElementNotInteractableError
      break
    end
  end

  # https://stackoverflow.com/a/55405357/7444594
  def click_element(element)
    script_string = 'var viewPortHeight = Math.max(document.documentElement.clientHeight, window.innerHeight || 0);' +
                    'var elementTop = arguments[0].getBoundingClientRect().top;' +
                    'window.scrollBy(0, elementTop-(viewPortHeight/2));'
    @driver.execute_script(script_string, element)
    @wait.until { element }
    element.click
  end
end
