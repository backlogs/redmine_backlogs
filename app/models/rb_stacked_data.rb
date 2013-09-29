# Each series added is expected to contain days, total points and closed points.
# When a series is added it is stacked on top of the previous one with the
# following rules applied:
# * New total series is stacked with the following properties:
#   * Points are accumulated with previous total series.
#   * Start date is added series own start date
#   * Last value of previous series is used when date exeeds previous series
# * Closed series is merged with previous using the following rules:
#   * Points are accumulated with current closed series.
#   * No data beyond closed_day_limit is accepted into the closed series
#     This is to avoid initial days with closed points of future releases to
#     affect the graph.
class RbStackedData
  def initialize(closed_day_limit)
    raise "Date should be supplied when creating RbStackedData!" unless closed_day_limit.is_a?(Date)
    @closed_day_limit = closed_day_limit
    @total_data = []
    @closed_data = Hash.new
    @closed_data[:days]= []
    @closed_data[:closed_points] = []
  end

  def add(arrays,name)
    if @total_data.size == 0
      add_first(arrays,name)
    else
      stack_total(arrays,name)
      merge_closed(arrays)
    end
  end

  def [](i)
    return @total_data[i]
  end

  attr_reader :closed_data
  attr_reader :total_data

  # Create data points for each overlapping day within the range of each series
  # This is sort of rippling up (and down!) missing days within each series.
  def add_overlapping_days
    return unless @total_data.size() > 1

    # Index arrays with offset
    idx_top = ((@total_data.size() -1)..1).to_a
    idx_bottom = ((@total_data.size() -2)..0).to_a

    # Ripple missing days down through the series
    _ripple_overlapping_days(idx_top,idx_bottom);
    # Ripple missing days up through the series
    _ripple_overlapping_days(idx_bottom,idx_top);
  end


private

  def add_first(arrays,name)
    @total_data << {:days => arrays[:days], :total_points => arrays[:total_points], :name => name}
    # Need to duplicate array of days. Otherwise ruby references falsely.
    days_within_limit = arrays[:days].select{|day| day <= @closed_day_limit}
    return if days_within_limit.size() == 0
    @closed_data[:days] = days_within_limit
    @closed_data[:closed_points] = arrays[:closed_points][0..(days_within_limit.size() - 1)]
  end

  def stack_total(arrays,name)
    # Have last stacked series ready when stacking the next
    last = @total_data.last

    tmp_total = []
    arrays[:days].each_with_index{|day,i|
      # Find closest date in last series (assumes sorted)
      idx = last[:days].find_index{|x| x > day}
      if idx.nil?
        # No days later than day. Use last one from previous series
        idx = last[:days].size() - 1
      else
        # Correct for search "x > day". We actually want the day itself
        # or the day closest to, but before actual day.
        idx -= 1 unless idx == 0
        # NOTE: if idx == 0 the series being added is actualy starting
        # before the previous series. The series should be added sorted
        # to avoid this. The series being added will stack days occuring
        # before previous start date with points from first day in the
        # previous series for now.
      end
      # Accumulate value for the day to the new stacked total series 
      tmp_total << arrays[:total_points][i] + last[:total_points][idx]
    }
    # Add the new stacked total series
    @total_data << {:days => arrays[:days], :total_points => tmp_total, :name => name}

  end

  def merge_closed(arrays)
    days_within_limit = arrays[:days].select{|x| x <= @closed_day_limit}
    new_days = days_within_limit - @closed_data[:days]
    common_days = @closed_data[:days] & days_within_limit
    old_days = @closed_data[:days] - days_within_limit

    _merge_closed_new(arrays,new_days)
    _merge_closed_common(arrays,common_days)
    _merge_closed_old(arrays,old_days)
  end

  # Merge all new days into @closed_data (sorted) 
  def _merge_closed_new(arrays,new_days)
    # Need to get a copy of days and closed points before starting to insert
    # days. Otherwise we will mixup data.
    closed_last_days = @closed_data[:days].dup
    closed_last_points = @closed_data[:closed_points].dup

    new_days.each{|day|
      array_idx = arrays[:days].find_index(day)
      closed_idx = @closed_data[:days].find_index{|x| x > day}
      if closed_idx.nil?
        # Add as last element
        @closed_data[:days] << day
        @closed_data[:closed_points] << arrays[:closed_points][array_idx] +
          (closed_last_points.size() > 0 ? closed_last_points.last : 0)
      else
        # Fetch index from old closed_data arrays
        prev_closed_idx = closed_last_days.find_index{|x| x > day}
        prev_closed_idx = prev_closed_idx - 1 unless prev_closed_idx.nil? || prev_closed_idx == 0
        closed_points_prev = 0
        closed_points_prev = closed_last_points[prev_closed_idx] unless prev_closed_idx.nil?

        # Add before index found in @closed_data
        @closed_data[:days].insert(closed_idx, day)
        @closed_data[:closed_points].insert(closed_idx, closed_points_prev +
                                            arrays[:closed_points][array_idx])
      end
    }
  end

  # Replace closed point values of days in common
  def _merge_closed_common(arrays, common_days)
    common_days.each{|day|
      array_idx = arrays[:days].find_index(day)
      closed_idx = @closed_data[:days].find_index(day)
      @closed_data[:closed_points][closed_idx] += arrays[:closed_points][array_idx]
    }
  end

  # Days represented only in the previous closed series.
  # Update with data from new days 
  def _merge_closed_old(arrays, old_days)
    old_days.each{|day|
      day_for_merge = arrays[:days].select{|x| x < day}.last
      unless day_for_merge.nil?
        closed_idx = @closed_data[:days].find_index(day)
        array_idx = arrays[:days].find_index(day_for_merge)
        @closed_data[:closed_points][closed_idx] += arrays[:closed_points][array_idx]
      end
    }
  end

  def _ripple_overlapping_days(idx_orig_arr,idx_next_arr)

    # Ripple missing days down the stacked totals
    idx_orig_arr.each_with_index{|orig_idx,i|
      next_idx=idx_next_arr[i]

      # Find first/last day of *previous* series.
      day_first = @total_data[next_idx][:days].first
      day_last = @total_data[next_idx][:days].last
      # Find all days in *current* series within date range of *previous*
      days_range = @total_data[orig_idx][:days].select{|d| d >= day_first && d <= day_last}
      # Find missing days in *previous* series
      days_missing = days_range - @total_data[next_idx][:days]
      # Add missing days to *previous* series duplicating total points from closest day before
      days_missing.each{|day|
        insert_idx = @total_data[next_idx][:days].find_index{|x| x > day }
        # due to selection previously we can assume day is always within range.
        @total_data[next_idx][:days].insert(insert_idx,day)
        @total_data[next_idx][:total_points].insert(insert_idx,@total_data[next_idx][:total_points][insert_idx - 1])
      }
    }
  end

end
