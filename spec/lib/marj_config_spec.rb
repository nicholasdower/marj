# frozen_string_literal: true

require_relative '../spec_helper'

describe MarjConfig do
  describe 'table_name' do
    it 'returns the default table name' do
      expect(MarjConfig.table_name).to eq('jobs')
    end

    it 'returns the configured table name' do
      MarjConfig.table_name = 'foo'
      expect(MarjConfig.table_name).to eq('foo')
    end
  end
end
