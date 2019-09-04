# NAME

Neo4j::TestBot::Data - Automated tests for graph metadata

# SYNOPSIS

    # install
    $ git clone https://github.com/CBIIT/neo-testbot.git
    $ cd neo-testbot
    $ perl Build.PL
    $ ./Build installdeps
    $ ./Build test
    $ ./Build install
    
    # run tests
    $ prove --source Graph t/my_data_tests.yaml

# DESCRIPTION

Neo4j::TestBot::Data provides a framework for automated testing of graph
metadata. Tests are based on specifying Neo4j queries along with
expected output from those queries. When queries return the expected
output, the test passes; otherwise, it fails.

Features:

- Neo4j::TestBot::Data allows tests to be specified and annotated in YAML files;
no coding is required.
- Neo4j::TestBot::Data is compatible with Perl's [TAP::Harness](https://metacpan.org/pod/TAP::Harness) framework; tests
can be executed with the built-in [prove](https://metacpan.org/pod/App::Prove) command, and can
benefit from its automatic test summarizing, aggregation, and
parallelization capabilities.
- Neo4j::TestBot::Data can will also log internal events fairly extensively
if desired, creating a log file separate from the test output. Logging
can be set to fire according to the desired severity level.
- When tests fail, the output of the query and test metadata is
automatically saved in a JSON format. The QA engineer can review the
data without having to rerun the query.
- Individual tests can be written to compare the results of more than
  one query.

# YAML Format for Test Suites

A suite of tests to run together can be specified in a YAML file. Top
level keys are for configuration, and the `tests` key points to an
array of objects that specify the tests.

    group : Informative test suite name
    logfile : my_run.log
    loglevel : DEBUG # <TRACE|DEBUG|TAP|INFO|ERROR|FATAL>
    verbosity : 1 # <0|1|2>
    save_dir : outdir # directory to save query results
    nosave : 0 # if 1, do not save results on test fails
    db_host : localhost # Neo4j HTTP endpoint - host
    db_port : 7474 # Neo4j HTTP endpoint - port
    tests :
      - name : Test1 # name required for each test
        desc : description of test (optional)
        query : |
           match (f) return count(f)
        expect : 1000
        evaluate : returns_n_rows
      - name : Test2
        desc : multiple queries here
        queries : # 'queries' is an array of queries
           - match (f:file) where not (f)--() return count(f)
           - match (f:file) where exists(f.uploaded)
        evaluate : return_same_n_rows
      - name : Test3
        desc : you can skip tests by adding a 'skip' key
        skip : Test 3 is being skipped for now...
      - name : Test4
        desc : |
          you can mark tests as 'to do' by adding a 'todo' key; 
          fails won't count against you
        todo : Get a round tuit

# Evaluators

The value of the `evaluate` key specifies the method to use to
evaluate the test. Some evaluators require an `expect` key to specify
the pass state.

- returns\_no\_rows
- returns\_some\_rows
- returns\_n\_rows

    `expect` should be the integer number of rows expected.

- returns\_count\_n

    Specify a query that returns a single row with a single value
(e.g., `... return count(n)`.
    `expect` should be the value expected.	

- returns\_value\_for\_field

    The query is executed and a single returned row is analyzed. Test outcome depends on the value of the `expect` paramenter:

        expect => $value

    Test succeeds if the first value of the returned row equals `$value`.

        expect => [$field => $value]

    Test succeeds if the row value of field `$field` equals `$value`

        expect => { $field1 => $value1, $field2 => $value2, ... }

    Test succeeds if for every `$field1`, `$field2`, ..., the returned values equal `$value1`, `$value2`, ... respectively.

- returns\_same\_n\_rows

    Specify two or more queries; each should return the same number of rows. 

- returns\_same\_counts

    Specify two or more queries that result in a single row with single
    value (e.g., `...return count(f)`). Test succeeds if that value is
    identical for every query.

# SEE ALSO

[Neo4j::TestBot::Data](lib/Neo4j/TestBot/README.Data.md), [Neo4j::TestBot::Data::Unit](lib/Neo4j/TestBot/Data/README.Unit.md), [TAP::Harness](https://metacpan.org/pod/TAP::Harness), [App::Prove](https://metacpan.org/pod/App::Prove).

# AUTHOR

    Mark A. Jensen
    FNLCR
    mark -dot- jensen -at- nih -dot- gov
