# frozen_string_literal: true

require 'spec_helper'

describe 'LOC' do
  loc = (Dir.glob('app/**/*.rb') + Dir.glob('lib/**/*.rb')).sum do |file|
    File.readlines(file).select do |line|
      line.strip.match(/^ *[^ #]/)
    end.size
  end

  it "LOC (#{loc}) does not exceed 100" do
    expect(loc).to be <= 100
  end
end
