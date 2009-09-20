#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'open-uri'
require 'net/http'
require 'uri'
require 'yaml'
require 'time'
require 'iconv'

def vkontakte_login(email, password)
  res = Net::HTTP.post_form(URI.parse("http://login.vk.com/"), { "email" => email, "pass" => password, "vk" => '', "act" => 'login' })
  sid = res.body.match(/value='([a-z0-9]+)'/)[1]
  raise "Vkontakte.ru authentication failed" if sid == 'nonenone'

  return sid
end

def vkontakte_set_status(txt, sid)
  f = open("http://vkontakte.ru", "Cookie" => "remixsid=#{sid}").read.to_s

  url = URI.parse("http://vkontakte.ru/profile.php")
  request = Net::HTTP::Post.new(url.path)

  request.set_form_data({'setactivity' => txt, 'activityhash' => f.match(/<input type='hidden' id='activityhash' value='([^']+)'>/)[1] })
  request['cookie'] = "remixsid=#{sid}"

  res = Net::HTTP.new(url.host, url.port).start { |http| http.request(request) }
end

config = YAML.load_file("config.yaml")

last_run_time = Time.at(open("last_run_time.txt").read.to_s.to_i) rescue nil
json = open("http://twitter.com/statuses/user_timeline.json?screen_name=#{config[:twitter][:screen_name]}&count=#{last_run_time.nil? ? 1 : 5}").read.to_s

posts = JSON.parse(json)
last_post_created_at = nil
sid = nil

posts.each do |p|
  created_at = Time.parse(p['created_at'])

  if last_run_time.nil? || created_at > last_run_time
    status = "[twitter] " + p['text']
    status = status[0...157] + "..." if status.length > 160

    sid ||= vkontakte_login(config[:vkontakte][:email], config[:vkontakte][:password])
    vkontakte_set_status(status, sid)
    puts "Status set: #{status}"

    last_post_created_at = created_at if last_post_created_at.nil? || created_at > last_post_created_at
  end
end

File.open("last_run_time.txt", "w") { |f| f.write(last_post_created_at.to_i) } if last_post_created_at
