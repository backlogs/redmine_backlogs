Given(/^I initialize RbStackedData with closed date (.*)$/) do |date|
  date = Time.zone.parse(date).to_date
  @stacked_data = RbStackedData.new(date)
end

Given(/^I add the following series "(.*)":$/) do |id,table|
  tmp_days = []
  tmp_total_points = []
  tmp_closed_points = []
  table.hashes.each do |entry|
    tmp_days << Time.zone.parse(entry[:days]).to_date
    tmp_total_points << entry[:total_points].to_i
    tmp_closed_points << entry[:closed_points].to_i
  end
  series = {:days => tmp_days, :total_points => tmp_total_points, :closed_points => tmp_closed_points}
  @stacked_data.add(series,id,true)
end

Given(/^I finish RbStackedData$/) do
  @stacked_data.finalize(true)
end


Then(/^series (\d+) should be:$/) do |series_number, table|
  idx = series_number.to_i
  expected_days = []
  expected_total = []
  table.hashes.each do |entry|
    expected_days << Time.zone.parse(entry[:days]).to_date
    expected_total << entry[:total_points].to_i
  end
  puts @stacked_data[idx].inspect
  @stacked_data[idx][:days].should == expected_days
  @stacked_data[idx][:total_points].should == expected_total
end

Then(/^closed series should be:$/) do |table|
  expected_days = []
  expected_closed = []
  table.hashes.each do |entry|
    expected_days << Time.zone.parse(entry[:days]).to_date
    expected_closed << entry[:closed_points].to_i
  end
  puts @stacked_data.closed_data.inspect
  @stacked_data.closed_data[:days].should == expected_days
  @stacked_data.closed_data[:closed_points].should == expected_closed
end

Then(/^series "(.*)" trend end date should be (.*)$/) do |id,date|
  date = Time.zone.parse(date).to_date
  @stacked_data.total_estimates[id][:end_date_estimate].should === date
end
