# NAME

Neo4j::TestBot::Data::Unit - graph data quality unit test

# SYNOPSIS

    use DBI;
    use Neo4j::TestBot::Data;
    $t = test( name => "All files have file type set", 
               desc => "longer description of test",
               query => "match (f:file) where not exists(f.type) return f",
               evaluate => 'returns_no_rows' );
    $t->dbh( DBI->connect("dbi:Neo4p:host=localhost;port=7474") );
    $t->run;
    print "Success\n" if $t->passed;

# DESCRIPTION

`Neo4j::TestBot::Data::Unit` objects represent unit tests on graph data
similar to `ok`, `is`, `is_deeply`, etc.  in [Test::More](https://metacpan.org/pod/Test::More). Rather
than using `Neo4j::TestBot::Data::Unit` directly, better to use
[Neo4j::TestBot::Data](./lib/Neo4j/TestBot/README.Data.md), which exposes this module, and emits
[TAP](https://testanything.org/tap-specification.html) that can be
used by [App::Prove](https://metacpan.org/pod/App::Prove), [TAP::Harness](https://metacpan.org/pod/TAP::Harness) and similar tools.

A `Neo4j::TestBot::Data::Unit` object is a named test, that runs a Neo4j Cypher
query against a database, and evaluates whether the test passes or
fails based on the information returned (or not returned) by the
query and the expected result provided by the user. 

The `evaluator` parameter is either a string (the name of one of the
built-in ["Evaluators"](#evaluators), or a code reference. The `expect` parameter
contains the expected result in a form required by the evaluator.

## Logging

Logging is provided by [Log::Log4perl](https://metacpan.org/pod/Log::Log4perl), which should be configured in
the test file that uses [Neo4j::TestBot::Data](./lib/Neo4j/TestBot/README.Data.md).

If a test fails (or if the logger is set at DEBUG)
`Neo4j::TestBot::Data::Unit` objects will save the query information and
the query result JSON (could be large). Hopefully this will save some
time for QA.

This information will save to the directory in the `save_dir()`
property (or the current working directory if that is not set).

The filenames will be

    <test_group>_<test_name_with_underscores>_<timestamp>.info.json
    <test_group>_<test_name_with_underscores>_<timestamp>_qry<n>.result.json

# METHODS

## Constructor new(), test()

`test` is exported as a main namespace alias.

    use Neo4j::TestBot::Data;
    $test = Neo4j::TestBot::Data::Unit->new( name => 'Goob', ....);
    # or
    $test = test( name => 'Goob', ...);

### Parameters

Parameters can only be set in the constructor. Each parameter has a corresponding getter:

    $test = test( name => 'Boog', ...);
    if ($test->name eq 'Boog') {
       ...
    }

- name
- desc
- queries

    Getter returns a plain array:

        @q = $test->queries;

- query

    Getter returns the first query as string:

        $q = $test->query;

- evaluate, expect

    Describes test proper. `evaluate` defaults to `returns_no_rows`. See ["Evaluators"](#evaluators).

## Evaluators

- returns\_no\_rows
- returns\_some\_rows
- returns\_n\_rows

    `expect` should be the integer number of rows expected.

- returns\_value\_for\_field

    The query is executed and a single returned row is analyzed. Test outcome depends on the value of the `expect` paramenter:

        expect => $value

    Test succeeds if the first value of the returned row equals `$value`.

        expect => [$field => $value]

    Test succeeds if the row value of field `$field` equals `$value`

        expect => { $field1 => $value1, $field2 => $value2, ... }

    Test succeeds if for every `$field1`, `$field2`, ..., the returned values equal `$value1`, `$value2`, ... respectively.

### Custom Evaluators

A code reference can be supplied to the `evaluator` parameter. The
only argument passed is the test object itself. After the test is
`run()`, the hashref `$test->{sth}` will contain the [DBI](https://metacpan.org/pod/DBI)
statement handle for each query. Keys for `$test->{sth}` are the
query statement strings themselves; that is

    $sth0 = $test->{sth}{"($test->queries)[0]"};
    $rowarrayref = $sth0->fetch;

If the test passes, set

    $self->{result} = 'ok';

If the test fails, set

    $self->{result} = 'not ok';
    $self->{comment} = '# reason for failure';

Any return value will be ignored.

Example:

    # always pass
    $unit->{evaluate} = sub { shift->{result} = 'ok' };
    

## run()

Call `run()` on the test object to execute the query(ies) and evaluator.

If the database handle has RaiseError set

    $test->dbh->{RaiseError} = 1;

then query failures are indicated by 

    $test->result eq 'not ok'

and the database error in $test->comment.

## Data methods

Data values are added in the evaluator method. Custom evaluators
(e.g., code refs) ideally should follow these conventions.

- result

    `undef` if not run, 'ok' if success, 'not ok' if failure.

- comment

    Contains a comment, starting with '#'. Will contain a reason for failure on fail.

- passed

    TRUE if passed, FALSE if failed/not run.

- date

    Timestamp of test (set when run), in format `YYYYMMDD.HH:MM.ZZZZ`.

## Getter/Setters

These properties may be set after construction.

- group() - Test group name

        $test->group('DR7.0-RC');

- dbh() - [DBD::Neo4p](https://metacpan.org/pod/DBD::Neo4p) database handle

        $dbh = DBI->connect(...);
        $dbh->{RaiseError} = 1;
        $test->dbh($dbh);

- save\_dir() - Directory for saving results

        $test->save_dir('testdir');

- nosave() - Override saving query responses on failure/debug

        $test->nosave(1);

# SEE ALSO

[Neo4j::TestBot::Data](./lib/Neo4j/TestBot/README.Data.md)

# AUTHOR

    Mark A. Jensen
    FNLCR
    mark -dot- jensen -at- nih -dot- gov
