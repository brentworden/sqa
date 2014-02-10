#!/usr/bin/env ruby
require 'optparse'

class QuerySummary
  def initialize(query)
    @calls = 1
	@averageQueryTime = query.query_time
	@averageLockTime = query.lock_time
	@averageRowsSent = query.rows_sent.to_f
	@averageRowsExamined = query.rows_examined.to_f
	@sql = query.sql
  end
  
  def calls
    return @calls
  end
  
  def rows_examined
    return @averageRowsExamined
  end
  
  def lock_time
    return @averageLockTime
  end
  
  def query_time
    return @averageQueryTime
  end
  
  def rows_sent
    return @averageRowsSent
  end
  
  def row_efficiency
    if @rowsExamined > 0
	  return @rowsSent.to_f / @rowsExamined.to_f
	end
	return 1.0
  end 
  
  def sql
    return @sql
  end

  def adjust_average(xbar, n, x)
    return xbar + ((x - xbar) / n)
  end
  
  def add_query(query)
    @calls += 1
	@averageQueryTime = adjust_average(@averageQueryTime, @calls.to_f, query.query_time)
	@averageLockTime = adjust_average(@averageLockTime, @calls.to_f, query.lock_time)
	@averageRowsSent = adjust_average(@averageRowsSent, @calls.to_f, query.rows_sent.to_f)
	@averageRowsExamined = adjust_average(@averageRowsExamined, @calls.to_f, query.rows_examined.to_f)
  end
  
  def row_efficiency
    if @averageRowsExamined > 0.0
	  return @averageRowsSent / @averageRowsExamined
	end
	return 1.0
  end 
  
  def is_valid (options)
    return @calls >= options[:minCalls] && 
	  @averageQueryTime >= options[:minQuery] &&
	  @averageLockTime >= options[:minLock] &&
	  @averageRowsSent >= options[:minRowsSent] &&
	  @averageRowsExamined >= options[:minRowsExamined] &&
	  row_efficiency <= options[:maxRowEfficiency]
  end
end

class Query
  def initialize(queryTime, lockTime, rowsSent, rowsExamined)
    @queryTime = queryTime.to_f
	@lockTime = lockTime.to_f
	@rowsSent = rowsSent.to_i
	@rowsExamined = rowsExamined.to_i
	@sql = nil
  end
  
  def rows_examined
    return @rowsExamined
  end
  
  def lock_time
    return @lockTime
  end
  
  def query_time
    return @queryTime
  end
  
  def rows_sent
    return @rowsSent
  end
  
  def row_efficiency
    if @rowsExamined > 0
	  return @rowsSent.to_f / @rowsExamined.to_f
	end
	return 1.0
  end 
  
  def sql
    return @sql
  end
  
  def add_sql(line)
    if @sql != nil
	  @sql = @sql + '\n' + line
	else 
      @sql = line
	end
  end
  
  def to_s
    return @sql
  end
end

def processFile (fileName, state)
  File.open(fileName, "r") do |file|
    file.each_line { |line| processLine(line, state) }
  end
end

def processLine (line, state)
  if line =~ /\#/
	if line =~ /\# Query_time:/
      # query start
	  matches = /\# Query_time\: (.+)  Lock_time\: (.+) Rows_sent\: (.+)  Rows_examined\: (.+)/.match(line)
	  state[:query] = Query.new(matches[1], matches[2], matches[3], matches[4]);
	else
	  query = state[:query]
	  if query != nil
	    summary = state[:summaries][query.sql.hash]
		if summary == nil
		  summary = QuerySummary.new(query)
		  state[:summaries][query.sql.hash] = summary
		else
		  summary.add_query(query)
		end
	  end
	  state[:query] = nil
	end
  elsif state[:query] != nil
    if line =~ /^SET timestamp/ || line =~ /^use/
	else
      # query sql
	  query = state[:query]
	  query.add_sql(line)
	end
  end
end

def sortSummaries(summaries, method)
  summaries.sort! {|x, y| x.send(method) <=> y.send(method) }
end

#===========================
# parse command line options
#===========================
options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: sqa.rb [options] file1 file2 ..."
  
  # default options
  options[:count] = 10
  options[:minCalls] = 1
  options[:minQuery] = 0.0
  options[:minLock] = 0.0
  options[:minRowsSent] = 0.0
  options[:minRowsExamined] = 0.0
  options[:maxRowEfficiency] = 1.0
  options[:sort] = :calls
  options[:ascending] = false
  
  # count
  opts.on('--count NUMBER', Integer, 'Number of items to report.') do |n|
    options[:count] = n
  end

  # minimum calls
  opts.on('--min-calls NUMBER', Integer, 'Minimum number of calls.') do |n|
    options[:minCalls] = n
  end

  # minimum query time
  opts.on('--min-query SECONDS', Float, 'Minimum average query time in seconds; can be in fraction of seconds.') do |d|
    options[:minQuery] = d
  end

  # minimum lock time
  opts.on('--min-lock SECONDS', Float, 'Minimum average lock time in seconds; can be in fraction of seconds.') do |d|
    options[:minLock] = d
  end

  # minimum rows sent
  opts.on('--min-rows-sent NUMBER', Float, 'Minimum average number of rows returned.') do |d|
    options[:minRowsSent] = d
  end

  # minimum rows examined
  opts.on('--min-rows-examined NUMBER', Float, 'Minimum average number of rows examined.') do |d|
    options[:minRowsExamined] = d
  end

  # minimum lock time
  opts.on('--max-row-efficiency PERCENT', Float, 'Maxinum row efficiency as expressed as a percentage.') do |d|
    options[:maxRowEfficiency] = d / 100.0
  end
  
  # sort ascending
  opts.on('-a', '--sort-ascend TYPE', 'How the items in the report are sorted. TYPE is one of calls, query, lock, sent, examine, or eff') do |s|
    options[:ascending] = true
    options[:sort] = :calls if s == 'calls';
    options[:sort] = :query_time if s == 'query';
    options[:sort] = :lock_time if s == 'lock';
    options[:sort] = :rows_sent if s == 'sent';
    options[:sort] = :rows_examined if s == 'examine';
    options[:sort] = :row_efficiency if s == 'eff';
  end
  
  # sort descending 
  opts.on('-d', '--sort-descend TYPE', 'How the items in the report are sorted. TYPE is one of calls, query, lock, sent, examine, or eff') do |s|
    options[:ascending] = false
    options[:sort] = :calls if s == 'calls';
    options[:sort] = :query_time if s == 'query';
    options[:sort] = :lock_time if s == 'lock';
    options[:sort] = :rows_sent if s == 'sent';
    options[:sort] = :rows_examined if s == 'examine';
    options[:sort] = :row_efficiency if s == 'eff';
  end
  
  # help
  opts.on( '-?', '--help', 'Display this screen' ) do
    puts opts
	exit
  end
end
optparse.parse!

#====================
# data initialization
#====================
state = {:query => nil, :summaries => {} }

#==============================================
# process files and accumulate query statistics
#==============================================
ARGV.each { |fileName| processFile(fileName, state) }

#=========================================
# select and sort results based on options
#=========================================
selectedSummaries = []
state[:summaries].each do |entry|
  summary = entry[1]
  selectedSummaries << summary if summary.is_valid(options)
end

sortSummaries(selectedSummaries, options[:sort])
if options[:ascending] == false
  selectedSummaries.reverse!
end

#===============
# output results
#===============
n = options[:count] - 1
puts "Calls  Query Time  Lock Time  Rows Sent  Rows Examined  Efficiency  SQL"
selectedSummaries[0..n].each_with_index do |summary, index|
  args = [summary.calls, summary.query_time, summary.lock_time, summary.rows_sent, summary.rows_examined, summary.row_efficiency * 100.0, index]
  puts "%5d  %10.3f  %9.3f  %9.2f  %13.2f  %10.1f  [%d] Below" % args
end

selectedSummaries[0..n].each_with_index do |summary, index|
  puts ""
  puts "[#{index}] SQL Statement:"
  puts summary.sql
end
