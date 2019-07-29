# NAME

Neo4j::TestBot::Data - Harness/Runner for graph data unit tests

# SYNOPSIS

    use Neo4j::TestBot::Data;
    my $log_conf =<<CONF;
     log4perl.rootLogger=DEBUG, A1
     log4perl.appender.A1=Log::Log4perl::Appender::Screen
     log4perl.appender.A1.layout=PatternLayout
     log4perl.appender.A1.layout.ConversionPattern=%d %C [%p] - %m%n
    CONF

    my $dbh = DBI->connect("dbi:Neo4p:host=localhost;port=7474");
    $dbh->{RaiseError} = 1;
    my $tester = Neo4j::TestBot::Data->new( dbh => $dbh, log_conf => \$log_conf );

     @tests = ( 
         test( name => 'No orphan file nodes',
    	desc => 'If there are orphan nodes, report; else, pass',
    	query => cypher->match('f')
    	  ->where([ -and => \'exists(f.file_name)',
    		    { -not => ptn->N('f')->to_N() }])
    	  ->return(\'count(f)'),
    	evaluate => 'returns_no_rows' ),
     );
	
    $tester->runtests( @tests );
    $dbh->disconnect;

    # prove/TAP::Harness can slurp TAP output
    $ prove tests/data-tests.t

# DESCRIPTION

`Neo4j::TestBot::Data` provides a system for creating, running, and logging
comprehensive tests of graph metadata. It allows the QA user to write
simple and well-annotated tests based on metadata database
queries. Tests can be grouped in single files based on topic or other
logical grouping. All test files may be run together using familiar
Perl tools. Test results are streamed in
[Test Anything Protocol](https://testanything.org/), a simple standard
that is understood by test aggregation and statistics generators in
several programming languages.

Tests are specified in a relatively simple syntax, with a name,
description, associated database queries, a method for evaluation of
the queries and expected results. Queries are made in [Neo4j](https://neo4j.com) Cypher and
executed against any Neo4j instance of the graph metadata. General query 
evaluators are provided by the module to reduce hand-coding.

When tests fail (or if logging level is set to DEBUG), test
information and the JSON results of test Cypher queries are stored in
a specified directory with timestamps and meaningful files names. The
idea is to simplify the follow up analysis of failing tests and help
get to root causes faster.

The main motivation for `Neo4j::TestBot::Data` is to reduce the energy
barrier to creating and regularly executing data tests. It attempts to
make it easy to quickly add a new test based on any new data fault,
and to run these tests as regressions automatically and to generate
automated reports of failures regularly. This should make it easier to
identify data or code changes responsible for data regressions and so
solve them more rapidly, when changes are fresh in the minds of the
team.


## TAP

[Test anything protocol
(TAP)](https://testanything.org/tap-specification.html) is output to
`STDOUT`. It can be read by [TAP::Harness](https://metacpan.org/pod/TAP::Harness), [prove](https://metacpan.org/pod/App::Prove),
etc.

Each test generates TAP output. The most basic response is

    ok

for passing tests, and 

    not ok

for failing tests. In addition, test descriptions can occur with the
test result, set off by the pound sign '#'. More detailed diagnostic
information can appear as text lines beginning with the pound sign.

The ["verbosity()"](#verbosity) method sets the extent of this diagnostic information.

## Logging

[Log::Log4perl](https://metacpan.org/pod/Log::Log4perl) is used to provide logging in addition to TAP.

# METHODS

- new()

    Create harness.

- <a name="runtests"></a>runtests()

    Runs tests represented by an array of [Neo4j::TestBot::Data::Unit](./Data/README.Unit.md) objects.

- <a name="verbosity"></a>verbosity()

    How much stuff output as TAP comment lines:

        Verbosity 0: output minimal TAP
        Verbosity 1: plus test description
        Verbosity 2: plus test method and Cypher query

- dbh()

    [DBD::Neo4p](https://metacpan.org/pod/DBD::Neo4p) (Neo4j) [DBI](https://metacpan.org/pod/DBI) database handle. Should be connected and
    {RaiseError} set. This is passed directly to each [Neo4j::TestBot::Data::Unit](./Data/README.Unit.md) object in ["runtests()"](#runtests).

- group()

    Create a name for the set of tests run by this `Neo4j::TestBot::Data`
    instance. Passes group name to each [Neo4j::TestBot::Data::Unit](./Data/README.Unit.md) object in
    ["runtests()"](#runtests). Group name is a prefix to all files saved.

- save\_dir()

    Directory to save any files created by the set of tests run by this `Neo4j::TestBot::Data`
    instance. Passes save\_dir to each [Neo4j::TestBot::Data::Unit](./Data/README.Unit.md) object in
    ["runtests()"](#runtests).

# SEE ALSO

[Neo4j::TestBot::Data::Unit](./Data/README.Unit.md), [DBD::Neo4p](https://metacpan.org/pod/DBD::Neo4p), [REST::Neo4p](https://metacpan.org/pod/REST::Neo4p), [App::Prove](https://metacpan.org/pod/App::Prove)

# AUTHOR

    Mark A. Jensen
    FNLCR
    mark -dot- jensen -at- nih -dot- gov
