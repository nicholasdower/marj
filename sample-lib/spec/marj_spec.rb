# frozen_string_literal: true

require_relative 'spec_helper'

describe Marj do
  before do
    Marj::Record.delete_all
  end

  it 'queries' do
    expect { TestJob.perform_later }.to change { Marj.query(:count) }.from(0).to(1)
  end

  it 'deletes jobs on success' do
    job = TestJob.perform_later
    expect { job.perform_now }.to change { Marj.query(:count) }.from(1).to(0)
  end
end
