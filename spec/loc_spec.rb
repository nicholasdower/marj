# frozen_string_literal: true

require 'spec_helper'

describe 'loc' do
  it 'does not exceed 100 lines of code' do
    loc = (Dir.glob('app/**/*.rb') + Dir.glob('lib/**/*.rb')).sum do |file|
      File.readlines(file).select do |line|
        line.strip.match(/^ *[^ #]/)
      end.size
    end
    expect(loc).to be <= 100
  end
end
