package Neo4j::TestBot::Data;
use v5.10;
use lib '../../../lib';
use Neo4j::TestBot::Data::Unit;
use DBI;
use Scalar::Util qw/blessed/;
use Try::Tiny;
use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use base Exporter;
use strict;
use warnings;
$|=1;

our $VERSION = '0.1000';
our @EXPORT = qw/test cypher ptn/;

# use Log::Log4perl to log
# INFO level - all TAP
# default - emit the TAP
# verbose v - plus query and test method name (or code) as TAP comment
# verbose vv - plus dump the query results as json on fail
# verbose vvv - vv for passing _and_ failing tests
# loglevel

# my $log_conf =<<CONF;
#  log4perl.rootLogger=ERROR, A1
#  log4perl.appender.A1=Log::Log4perl::Appender::Screen
#  log4perl.appender.A1.layout=PatternLayout
#  log4perl.appender.A1.layout.ConversionPattern=%d %C [%p] - %m%n
# CONF

our $logger;
our $TAP;
Log::Log4perl::Logger::create_custom_level('TAP','INFO');

sub new {
  my $class = shift;
  my %args = @_;
  my $self = {
    dbh => undef,
    verbosity => 0,
    _results => [],
    output => 'stdout',
  };
  bless $self, $class;
  while ( my ($k,$v) = each %args ) {
    $self->{$k} = $v;
  }
  #  Log::Log4perl::init($self->{log_conf} || \$log_conf);
  $self->_build_logger;
  if ($self->{loglevel}) {
    $self->{loglevel} =
      ($self->{loglevel} =~ /^TRACE|DEBUG|TAP|INFO|WARN|ERROR|FATAL$/i ?
       eval '$'.uc($self->{loglevel}) :
       $self->{loglevel});
    $logger->level($self->{loglevel});
  }
  $logger->debug("Create Neo4j::TestBot::Data runner object");
#  while (my ($k, $v) = each %$self) {say "$k : $v";}
  return $self;
}

sub dbh { shift->{dbh} }
sub group { $_[1] ? ($_[0]->{group} = $_[1]) : $_[0]->{group} }
sub output { $_[1] ? ($_[0]->{output} = $_[1]) : $_[0]->{output} }
sub save_dir { $_[1] ? ($_[0]->{save_dir} = $_[1]) : $_[0]->{save_dir} }
sub verbosity { $_[1] ? ($_[0]->{verbosity} = $_[1]) : $_[0]->{verbosity} }

# here -- generate an annotated stream of TAP
# this could be output and captured by harness
# standardize - render name, desc, result with appropriate index number

sub runtests {
  $logger->debug("Enter runtests()");
  my $self = shift;
  my @tests = @_;
  $logger->debug(@tests." provided to runtests()");
  my $tap;
  if ($self->dbh && !$self->dbh->ping) {
    $logger->tap("1..0");
    $self->_emit('1..0');
    $logger->tap("Bail out ! Database not connected");
    $self->_emit('Bail out ! Database not connected');
    $logger->error('Database not connected : bailed');
    return;
  }
  $tap = '1..'.scalar(@tests);
  $logger->tap($tap);
  $self->_emit($tap);
  if ($self->group) {
    $tap ="# test group ".$self->group;
    $self->_emit($tap);
    $logger->tap($tap);
  }
  my $ct=0;
  for my $test (@tests) {
    unless (blessed($test) and $test->isa('Neo4j::TestBot::Data::Unit')) {
      $logger->warn("Skipping a test that is not a 'Neo4j::TestBot::Data::Unit' object");
      next;
    }
    $ct++;
    #auto set dbh if the Test object has defined it
    $test->dbh($self->dbh) if ($self->dbh);
    $self->group && $test->group( $self->group );
    if ($self->save_dir) {
      mkdir $self->save_dir unless -x $self->save_dir;
      $test->save_dir( $self->save_dir );
    }
    try {
      $test->run;
    } catch {
      $logger->error("test execution failure: '$_'");
      $test->{comment} = "test execution failure : $_";
      $test->{result} = 'not_ok';
    };
    $tap = join(' ',$test->result, $ct, $test->name, $test->directive // '');
    $logger->tap($tap);
    $self->_emit($tap);
    if ($test->result ne 'ok') {
      $logger->tap($test->comment);
      $self->_emit($test->comment);
    }
    for ($self->verbosity) {
      ($_ >= 1) && do {
	$tap="# test description: ".($test->desc // '<none>');
	$logger->tap($tap);
	$self->_emit($tap);
      };
      ($_ >= 2) && do {
	$tap = "# test method - ".
	  (ref $test->evaluate ? 'custom' : $test->evaluate);
	$logger->tap($tap);
	$self->_emit($tap);
	for my $q ($test->queries) {
	  $tap = "# qry: $q";
	  $logger->tap($tap);
	  $self->_emit($tap);
	}
      };
      ($_ >= 3) && do {
	1;
      };
      last;
    }
  }
}

sub _emit {
  my $self = shift;
  my ($str) = @_;
  for ($self->{output}) {
    ref && say $_ $str;
    /^stdout$/ && say $str;
    /^collect$/ && push(@{$self->{_results}},$str);
  }
}

sub _build_logger {
  my $self = shift;
  if ($self->{logconf}) {
    my $conf = $self->{logconf};
    Log::Log4perl::init(\$conf);
    return $logger = Log::Log4perl->get_logger("");
  }
  my $layout = Log::Log4perl::Layout::PatternLayout->new('%d %C [%p] - %m%n');
  my @app_args;
  if ($self->{logfile}) {
    @app_args = (
      'Log::Log4perl::Appender::File',
      filename => $self->{logfile},
      name => 'A1',
     );
  }
  else {
    @app_args = (
      'Log::Log4perl::Appender::Screen',
      stderr => 1,
      name => 'A1',
     );
  }
  my $app = Log::Log4perl::Appender->new(@app_args);
  $app->layout($layout);
  $logger = Log::Log4perl->get_logger();
  $logger->add_appender($app);
  return $logger;
}

sub results { shift->{_results} }

=head1 NAME

Neo4j::TestBot::Data - Harness/Runner for graph data unit tests

=head1 SYNOPSIS

 use Neo4j::TestBot::Data;
 my $dbh = DBI->connect("dbi:Neo4p:host=localhost;port=7474");
 $dbh->{RaiseError} = 1;

 my $tester = Neo4j::TestBot::Data->new( 
   dbh => $dbh, 
   save_dir => 'demo',
   logfile => 'demo/try.log'
 );

 @tests = ( 
     test( name => 'No orphan file nodes',
	desc => 'If there are orphan nodes, report; else, pass',
	query => cypher->match('f')
	  ->where([ -and => \'exists(f.file_name)',
		    { -not => ptn->N('f')->to_N() }])
	  ->return(\'count(f)'),
	evaluate => 'returns_no_rows' ),
	),
 );
 $tester->runtests( @tests );
 $dbh->disconnect;

 # prove/TAP::Harness can slurp TAP output
 $ prove tests/data-tests.t

=head1 DESCRIPTION

C<Neo4j::TestBot::Data> provides a system for creating, running, and
logging comprehensive tests of graph  metadata. It allows the QA user to
write simple and well-annotated tests based on metadata database
queries. Tests can be grouped in single files based on topic or other
logical grouping. All test files may be run together using familiar
Perl tools. Test results are streamed in Test Anything Protocol, a
simple standard that is understood by test aggregation and statistics
generators in several programming languages.

Tests are specified in a relatively simple syntax, with a name,
description, associated database queries, a method for evaluation of
the queries and expected results. Queries are made in Neo4j Cypher and
executed against any Neo4j instance of the graph metadata. General query 
evaluators are provided by the module to reduce hand-coding.

When tests fail (or if logging level is set to DEBUG), test
information and the JSON results of test Cypher queries are stored in
a specified directory with timestamps and meaningful files names. The
idea is to simplify the follow up analysis of failing tests and help
get to root causes faster.

The main motivation for C<Neo4j::TestBot::Data> is to reduce the energy
barrier to creating and regularly executing data tests. It attempts to
make it easy to quickly add a new test based on any new data fault,
and to run these tests as regressions automatically and to generate
automated reports of failures regularly. This should make it easier to
identify data or code changes responsible for data regressions and so
solve them more rapidly, when changes are fresh in the minds of the
team.

=head2 TAP

L<Test anything protocol
(TAP)|https://testanything.org/tap-specification.html> is output to
C<STDOUT>. It can be read by L<TAP::Harness>, L<prove|App::Prove>,
etc.

Each test generates TAP output. The most basic response is

 ok

for passing tests, and 

 not ok

for failing tests. In addition, test descriptions can occur with the
test result, set off by the pound sign '#'. More detailed diagnostic
information can appear as text lines beginning with the pound sign.

The L</verbosity()> method sets the extent of this diagnostic information.

=head2 Logging

L<Log::Log4perl> is used to provide logging in addition to TAP.

=head1 METHODS

=over

=item new()

Create harness.

=item runtests()

Runs tests represented by an array of L<Neo4j::TestBot::Data::Unit> objects.

=item verbosity()

How much stuff output as TAP diagnostic (comment) lines:

 Verbosity 0: output minimal TAP
 Verbosity 1: plus test description
 Verbosity 2: plus test method and Cypher query

=item dbh()

L<DBD::Neo4p> (Neo4j) L<DBI> database handle. Should be connected and
{RaiseError} set. This is passed directly to each L<Neo4j::TestBot::Data::Unit> object in L</runtests()>.

=item group()

Create a name for the set of tests run by this C<Neo4j::TestBot::Data>
instance. Passes group name to each L<Neo4j::TestBot::Data::Unit> object in
L</runtests()>. Group name is a prefix to all files saved.

=item save_dir()

Directory to save any files created by the set of tests run by this C<Neo4j::TestBot::Data>
instance. Passes save_dir to each L<Neo4j::TestBot::Data::Unit> object in
L</runtests()>.

=back

=head1 SEE ALSO

L<Neo4j::TestBot::Data::Unit>, L<DBD::Neo4p>, L<REST::Neo4p>, L<App::Prove>

=head1 AUTHOR

 Mark A. Jensen
 FNLCR
 mark -dot- jensen -at- nih -dot- gov

=cut

1;
