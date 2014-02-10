# sqa

**sqa** is a Ruby script to analyze MySQL query logs.  **sqa** is capable of examining query logs and determining the most frequently executed SQL statements, the statements that examine the most records, the statements that take the longest amount of time, and more discoveries based on other important metrics.

## Usage
### Basic Execution
    $> sqa.rb path/to/mysql-slow-query.log
This analyzes the given log file and reports the top 10 most frequently executed SQL statements.

### Multiple Log Files
    $> sqa.rb path/to/first-slow-query.log path/to/second-slow-query.log
This analyzes all the given log files and reports the top 10 most frequently executed SQL statements.

### Command Line Usage
    Usage: sqa.rb [options] file1 file2 ...
        --count NUMBER               Number of items to report.
        --min-calls NUMBER           Minimum number of calls.
        --min-query SECONDS          Minimum average query time in seconds; can be in fraction of seconds.
        --min-lock SECONDS           Minimum average lock time in seconds; can be in fraction of seconds.
        --min-rows-sent NUMBER       Minimum average number of rows returned.
        --min-rows-examined NUMBER   Minimum average number of rows examined.
        --max-row-efficiency PERCENT Maxinum row efficiency as expressed as a percentage.
    -a, --sort-ascend TYPE           How the items in the report are sorted. TYPE is one of calls, query, lock, sent, examine, or eff
    -d, --sort-descend TYPE          How the items in the report are sorted. TYPE is one of calls, query, lock, sent, examine, or eff
    -?, --help                       Display this screen

## Examples

### Top N Statements
Use the --count NUMBER command line option to control how many statements are returned in the final report.  By default, the top 10 statements are reported.

    $> sqa.rb --count 100 mysql-slow-query.log
This reports the top 100 statements.

### Filter out Low Frequency Statements
Use the --min-calls NUMBER command line option to filter out low freqency statements from the final report.  By default, all calls are included in the analysis.

    $> sqa.rb --min-calls 100 mysql-slow-query.log
This reports only statements which were executed at least 100 times.

### Filter out Fast Executing Statements
Use the --min-query SECONDS command line option to filter out statements with a small, average query time.  By default, all calls are included in the analysis.

    $> sqa.rb --min-query 2 mysql-slow-query.log
This reports only statements which had an average query time of 2 seconds or more.
