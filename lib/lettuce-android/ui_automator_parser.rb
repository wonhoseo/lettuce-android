#!/usr/bin/env ruby -wKU
# encoding: utf-8

require 'nokogiri'
require 'lettuce-android/view'

module Lettuce module Android

  class UiAutomatorParser < Nokogiri::XML::SAX::Document
    
    attr_reader :root
    attr_reader :views
    
    def initialize device, version
      @device = device
      @version = version
      @root = nil
      @views = []
      @node_stack = []
      @parent = nil
      @id_count = 1      
    end
    
    def start_element element, attributes = []
      if element == 'hierarchy'
        # do nothing
      elsif element == 'node'
        # Instantiate an Element object
        attributes_hash = Hash[attributes.map{|key,value|[key,value]}]
        attributes_hash ['uniqueId'] = "id/no_id/%d" % [@id_count]
        @id_count += 1
        bounds = attributes_hash['bounds']
        # pattern: [x1,y1][x2,y2]
        if /\[(?<left>\d+),(?<top>\d+)\]\[(?<right>\d+),(?<bottom>\d+)\]/ =~ bounds
          attributes_hash['bounds'] = [[left.to_i, top.to_i],[right.to_i, bottom.to_i]]
        end
        child_view = View.factory(attributes_hash, @device, @version)
        views << child_view
        if @node_stack.empty?
          @root = child_view
        else
          @parent = @node_stack.last
          @parent.add(child_view)
        end
        @node_stack.push(child_view)
      end
    end
    
    def end_element element
      if element == 'hierarchy'
            # do nothing
      elsif element == 'node'
        @node_stack.pop()
      end
    end
    
    def characters(text)
      # do nothings
    end
  end
  
end end
