# frozen_string_literal: true

require 'spec_helper'

# It is ok to change this test if you need to add more lines of code. It is just a friendly reminder to keep it minimal.
describe 'LOC' do
  loc = Dir.glob('lib/**/*.rb').sum do |file|
    File.readlines(file).select do |line|
      line.strip.match(/^ *[^ #]/)
    end.size
  end

  it "LOC (#{loc}) does not exceed 250" do
    expect(loc).to be <= 250
  end
end
