# Copyright (C) 2012 Directed Edge, Inc.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'set'

module DirectedEdge
  class ContainerProxy
    attr_reader :cached_data, :add_queue, :remove_queue

    SUPPORTED_TYPES = [ Array, Hash, Set ]

    def initialize(klass, &loader)
      @cached = false
      @cached_data = klass.new
      @add_queue = klass.new
      @remove_queue = klass.new
      @loader = loader
    end

    def add(value)
      if cached?
        if array?
          @cached_data.push(value)
        elsif set?
          @cached_data.add(value)
        elsif hash?
          @cached_data.merge!(value)
        end
      else
        if array?
          @add_queue.push(value)
          @remove_queue.delete(value)
        elsif set?
          @add_queue.add(value)
          @remove_queue.delete(value)
        elsif hash?
          @add_queue.merge!(value)
          @remove_queue.delete(value.keys.first)
        end
      end
      value
    end

    def remove(value)
      if cached?
        if array? || set?
          @cached_data.delete(value)
        elsif hash?
          @cached_data.delete(value.is_a?(Hash) ? value.keys.first : value)
        end
      else
        if array?
          @remove_queue.push(value)
          @add_queue.delete(value)
        elsif set?
          @remove_queue.add(value)
          @add_queue.delete(value)
        elsif hash?
          @remove_queue.merge!((value.is_a?(Hash) ? value.keys.first : value) => nil)
          @add_queue.delete(value.is_a?(Hash) ? value.keys.first : value)
        end
      end
      value
    end

    def set(values)
      @cached = true
      @cached_data = values

      @add_queue.each { |v| add(v) }
      @remove_queue.each { |v| remove(v) }

      @add_queue.clear
      @remove_queue.clear

      values
    end

    def cached?
      @cached
    end

    private

    def method_missing(name, *args, &block)
      SUPPORTED_TYPES.each do |type|
        return @cached_data.is_a?(type) if name.to_s == "#{type.name.downcase}?"
      end

      @loader.call unless cached?
      @cached_data.clone.freeze.send(name, *args, &block)
    end
  end
end