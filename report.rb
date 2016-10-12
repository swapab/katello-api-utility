#!/usr/bin/env ruby

require 'socket'
require 'json'
require 'rest-client'
require 'pry'
require 'csv'

username,password,hostname = ARGV

hostname = hostname || Socket.gethostname

puts "Username: #{username}"
puts "Password: #{password}"
puts "Hostname: #{hostname}"

class Report
  attr_accessor :username, :password, :hostname, :api_caller

  def initialize(username, password, hostname)
    @username = username
    @password = password
    @hostname = hostname
    @api_caller = ApiCaller.new(username, password, hostname)
  end

  def generate
    hosts = JSON.parse(all_hosts)["results"]
    host_ids = hosts.map{|host| host["id"]}

    final_csv = CSV.generate do |csv|
      csv << ["Hostname", "IP", "Packages"]
      hosts.each do |host|
        puts host["id"]
        csv << [host["name"], host["ip"], enabled_products_per_host(host["id"])]
      end
    end

    File.open(File.expand_path('~/reports.csv'), 'w:UTF-8') { |file| file.write(final_csv) }
  end

  def enabled_products_per_host(host_id)
    product_content = JSON.parse(api_caller.get("/api/v2/hosts/#{host_id}/subscriptions/product_content"))["results"]

    product_content.inject([]) { |filtered_content_array, result_hash|
      filtered_content_array << result_hash["content"]["name"] if result_hash["enabled"]
      filtered_content_array
    }.join(",")
  rescue RestClient::ResourceNotFound,URI::InvalidURIError,RestClient::BadRequest => e
    ""
  end

  def all_content_views
    api_caller.get("/katello/api/content_views")
  end

  def all_hosts
    api_caller.get("/api/hosts")
  end

  def package_per_host(host_id)
    api_caller.get("/api/hosts/#{host_id}/packages")
  end
end

class ApiCaller < Struct.new(:username, :password, :hostname)
  attr_accessor :http_client

  def initialize(username, password, hostname)
    @http_client = RestClient::Request
    super
  end

  def get(path)
    http_client.execute(
      method: :get,
      url: parse(path),
      user: username,
      password: password,
      verify_ssl: false)
  end

  def parse(path)
    URI("https://#{hostname}#{path}").to_s
  end
end

report = Report.new(username, password, hostname)
report.generate
