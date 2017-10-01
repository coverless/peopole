#!/usr/bin/env ruby

system('git pull origin master')

require_relative '../judge'
TheJudge.new.post_top_50
