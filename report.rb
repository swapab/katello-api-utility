#!/usr/bin/env ruby

require 'socket'
require 'json'
require 'rest-client'
require 'pry'
require 'csv'

puts "========= Generating CSV ========"

username,password,hostname,filepath = ARGV

hostname = hostname || Socket.gethostname

FILEPATH = filepath || "~/reports.csv"

puts "Username: #{username}"
puts "Password: #{password}"
puts "Hostname: #{hostname}"
puts "Filepath: #{File.expand_path(FILEPATH)}"

puts "=> Computing... Hold on"

class Report
  attr_accessor :username, :password, :hostname, :api_caller

  def initialize(username, password, hostname)
    @username = username
    @password = password
    @hostname = hostname
    @api_caller = ApiCaller.new(username, password, hostname)
  end

  def generate
    hosts = get_all_hosts
    host_ids = hosts.map{|host| host["id"]}

    final_csv = CSV.generate do |csv|
      csv << ["Hostname", "IP", "Packages"]
      hosts.each do |host|
        csv << [host["name"], host["ip"], enabled_products_per_host(host["id"])]
      end
    end

    File.open(File.expand_path(FILEPATH), 'w:UTF-8') { |file| file.write(final_csv) }
  end

  def enabled_products_per_host(host_id)
    product_content = get_product_content_per_host(host_id)

    product_content.inject([]) { |filtered_content_array, result_hash|
      filtered_content_array << result_hash["content"]["name"] if result_hash["enabled"]
      filtered_content_array
    }.join(",")
  rescue RestClient::ResourceNotFound,URI::InvalidURIError,RestClient::BadRequest => e
    ""
  end

  def get_all_hosts
    api_caller.get("/api/hosts")
  end

  def get_product_content_per_host(host_id)
    api_caller.get("/api/v2/hosts/#{host_id}/subscriptions/product_content")
  end
end

class ApiCaller < Struct.new(:username, :password, :hostname)
  def http_client
    RestClient::Request
  end

  def get(path)
    JSON.parse(
      http_client.execute(
        method: :get,
        url: parse(path),
        user: username,
        password: password,
        verify_ssl: false)
    )["results"]
  end

  def parse(path)
    URI("https://#{hostname}#{path}").to_s
  end
end

report = Report.new(username, password, hostname)
report.generate

puts "========= Done ======== | File saved : #{FILEPATH}"
