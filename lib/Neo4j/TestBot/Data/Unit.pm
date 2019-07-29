package Neo4j::TestBot::Data::Unit;
use lib '../../../../lib';
use Neo4j::TestBot::Data::Helper;
use DBI;
use JSON;
use Try::Tiny;
use File::Copy;
use Scalar::Util qw/looks_like_number/;
use Log::Log4perl;
use Neo4j::Cypher::Abstract qw/cypher ptn/;
use base Exporter;
use strict;
use warnings;

our $VERSION = '0.1000';

# graph data test object - represents a single test
our @EXPORT = qw/test cypher ptn/;
our $logger = Log::Log4perl->get_logger(__PACKAGE__);

sub test { __PACKAGE__->new(@_) }

# create with hash of arguments
# Unit->new( name => $test_name, desc => $test_desc, dbh=>$neo4p_handle, queries = > [$cypher, ...],
#            evaluate => $name_of_eval_method_or_code_ref, expect => $value_expected )

# evaluate - can be a callback: first argument is test object, do test and put 'ok' or 'not ok' in
#            {result} property; if 'not ok', put comment in {comment} property.
#            compare (in whatever natural way) to the perl value in {expect} property.
#            statement handle for each query provided to object in {sth}{"$query"}
#            up to the evaluator methods to pull what they want from the exectuted statement

# make sure dbh has RaiseError set (but not in Unit; above it)
# logging

# most props are getter only (set in new() )
# dbh has a setter - since may wish to easily apply a test to other dbs

sub new {
  my $class = shift;
  my %args = @_;
  my $self = {
    name => undef,
    desc => undef,
    queries => [],
    dbh => undef,
    responses => {},
    result => undef,
    evaluate => 'returns_no_rows',
    expect => undef,
    group => '',
    save_dir => '',
    nosave => undef,
    date => undef,
  };
  bless $self, $class || __PACKAGE__;
  while ( my ($k,$v) = each %args ) {
    if ($k eq 'query') {
      if (ref $v ne 'ARRAY') { # assume a single query
	push @{$self->{queries}}, $v;
      }
    }
    else {
      $self->{$k} = $v;
    }
  }
  unless ($self->name) {
    $logger->logcroak("'name' is a required argument; please name this test");
  }
  $logger->debug("Create new unit test ", $self->name);
  if (!ref($self->{evaluate})) {
    $logger->logcroak("Evaluation '$$self{evaluate}' unknown") unless $self->can($self->{evaluate});
  }
  elsif (ref($self->{evaluate}) ne 'CODE') {
    $logger->logcroak("Can't understand the 'evaluate' argument");
  }
  return $self;
}

sub name { shift->{name} }
sub desc { shift->{desc} }
sub date { shift->{date} }
sub queries { @{shift->{queries}} }
sub query { ${shift->{queries}}[0] }
sub result { shift->{result} }
sub expect { shift->{expect} }
sub evaluate { shift->{evaluate} }
sub directive { shift->{directive} }
sub comment { shift->{comment} }
sub passed { shift->{result} =~ /^ok/ }
sub skip { shift->{skip} }
sub todo { shift->{todo} }
sub save_dir { $_[1] ? ($_[0]->{save_dir} = $_[1]) : $_[0]->{save_dir} }
sub nosave { $_[1] ? ($_[0]->{nosave} = $_[1]) : $_[0]->{nosave} }
sub group { $_[1] ? ($_[0]->{group} = $_[1]) : $_[0]->{group} }
sub dbh {  !defined $_[1] ? $_[0]->{dbh} : ($_[0]->{dbh} = $_[1]) }


# run the test
sub run {
  my $self = shift;
  $logger->debug("Run unit test ", $self->name, " - begin");
  $self->{date} = get_date();
  # handle skipped test
  if ($self->skip) {
    $logger->info("Test ".$self->name." skipped with '".$self->skip."'");
    $self->{result} = 'ok';
    $self->{directive} = '# SKIP '.$self->skip;
    return $self->result;
  }
  if ($self->todo) {
    $logger->info("Test ".$self->name." is marked TODO with '".$self->todo."'");
    $self->{directive} = '# TODO '.$self->todo;
  }
  # do queries
  unless ($self->{dbh} || !@{$self->{queries}}) {
    $logger->logcarp("Need Neo4p handle");
    $self->{result} = 'not ok';
    $self->{comment} = '# no database handle provided';
    return $self->result;
  }
  if ($self->dbh) {
    $logger->warn("RaiseError not set in db handle") unless $self->dbh->{RaiseError};
  }
  for (@{$self->{queries}}) {
    my $sth;
    try {
      $sth = $self->dbh->prepare("$_");
      $sth->execute(); # parameters?
    } catch {
      $logger->logcroak("Neo4j query failed: $_");
    };
    $self->{sth}{"$_"} = $sth;
  }
  # evaluate test
  for ($self->{evaluate}) {
    if (!ref()) {
      $self->$_();
    }
    elsif (ref() eq 'CODE') {
      $_->($self);
    }
  }
  # if test fails, or if logger is set to DEBUG or lower, save the query result
  unless ($self->passed or !$self->query or $self->nosave or !$logger->is_debug()) {
    my $savename = join("_",$self->group, $self->name, $self->date);
    $savename =~ tr/ /_/s;
    my $savepath = File::Spec->catfile($self->save_dir || '.', $savename);
    $logger->info("Saving test info for test '".$self->name."'");
    try {
      open my $f,'>', "$savepath.info.json" or die $!;
      my %info;
      @info{qw/name desc result queries evaluate expect group save_dir/}= @{$self}{qw/name desc result queries evaluate expect group save_dir/}; # 
      $_ = "$_" for @{$info{queries}}; # stringify everything 
      say $f encode_json \%info;
      close $f;
    } catch {
      $logger->error("Problem saving test info: $_");
    };
    my $i=0;
    for my $q (@{$self->{queries}}) {
      $i++;
      $logger->info("Saving query result for query :$q:");
      try {
	my $qobj = $self->{sth}{"$q"}->{neo_query_obj};
	reset_query($qobj); # this allows query obj to reparse the results from the temp file
	open my $f, ">", $savepath."_qry$i.result.json" or die;
	say $f encode_json $qobj->{NAME};
	print $f '[';
	my $row = $qobj->fetch;
	print $f encode_json($row) if defined $row;
	while (my $row = $qobj->fetch) {
	  print $f ', ';
	  say $f encode_json $row;
	}
	say $f ']';
	close $f;
      } catch {
	$logger->error("Problem saving query result: $_");
      };
    }
  }
  # return TAP
  $logger->debug("Run unit test ", $self->name, " - complete");
  $logger->debug("- result ".$self->result);
  $self->result;
}

sub get_date {
  my ($d) = `date '+%Y%m%d.%H:%M.%z'`;
  $logger->logcarp("Couldn't get system date: $!") if $?;
  chomp $d;
  return $d;
}

=head1 NAME

Neo4j::TestBot::Data::Unit - graph data quality unit test

=head1 SYNOPSIS

 use DBI;
 use Neo4j::TestBot::Data;
 $t = test( name => "All files have file type set", 
            desc => "longer description of test",
            query => "match (f:file) where not exists(f.type) return f",
            evaluate => 'returns_no_rows' );
 $t->dbh( DBI->connect("dbi:Neo4p:host=localhost;port=7474") );
 $t->run;
 print "Success\n" if $t->passed;

=head1 DESCRIPTION

C<Neo4j::TestBot::Data::Unit> objects represent unit tests on graph data
similar to C<ok>, C<is>, C<is_deeply>, etc.  in L<Test::More>. Rather
than using C<Neo4j::TestBot::Data::Unit> directly, better to use
L<Neo4j::TestBot::Data>, which exposes this module, and emits
L<TAP|https://testanything.org/tap-specification.html> that can be
used by L<App::Prove>, L<TAP::Harness> and similar tools.

A C<Neo4j::TestBot::Data::Unit> object is a named test, that runs a Neo4j Cypher
query against a database, and evaluates whether the test passes or
fails based on the information returned (or not returned) by the
query and the expected result provided by the user. 

The C<evaluator> parameter is either a string (the name of one of the
built-in L</Evaluators>, or a code reference. The C<expect> parameter
contains the expected result in a form required by the evaluator.

=head2 Logging

Logging is provided by L<Log::Log4perl>, which should be configured in
the test file that uses L<Neo4j::TestBot::Data>.

If a test fails (or if the logger is set at DEBUG)
C<Neo4j::TestBot::Data::Unit> objects will save the query information and
the query result JSON (could be large). Hopefully this will save some
time for QA.

This information will save to the directory in the C<save_dir()>
property (or the current working directory if that is not set).

The filenames will be

 <test_group>_<test_name_with_underscores>_<timestamp>.info.json
 <test_group>_<test_name_with_underscores>_<timestamp>_qry<n>.result.json

=head1 METHODS

=head2 Constructor new(), test()

C<test> is exported as a main namespace alias.

 use Neo4j::TestBot::Data;
 $test = Neo4j::TestBot::Data::Unit->new( name => 'Goob', ....);
 # or
 $test = test( name => 'Goob', ...);

=head3 Parameters

Parameters can only be set in the constructor. Each parameter has a corresponding getter:

 $test = test( name => 'Boog', ...);
 if ($test->name eq 'Boog') {
    ...
 }

=over

=item * name

=item * desc

=item * queries

Getter returns a plain array:

 @q = $test->queries;

=item * query

Getter returns the first query as string:

 $q = $test->query;

=item * evaluate, expect

Describes test proper. C<evaluate> defaults to C<returns_no_rows>. See L</Evaluators>.

=back

=head2 Evaluators

=over

=item * returns_no_rows

=item * returns_some_rows

=item * returns_n_rows

C<expect> should be the integer number of rows expected.

=item * returns_value_for_field

The query is executed and a single returned row is analyzed. Test outcome depends on the value of the C<expect> paramenter:

 expect => $value

Test succeeds if the first value of the returned row equals C<$value>.

 expect => [$field => $value]

Test succeeds if the row value of field C<$field> equals C<$value>

 expect => { $field1 => $value1, $field2 => $value2, ... }

Test succeeds if for every C<$field1>, C<$field2>, ..., the returned values equal C<$value1>, C<$value2>, ... respectively.

=back

=head3 Custom Evaluators

A code reference can be supplied to the C<evaluator> parameter. The
only argument passed is the test object itself. After the test is
C<run()>, the hashref C<$test-E<gt>{sth}> will contain the L<DBI>
statement handle for each query. Keys for C<$test-E<gt>{sth}> are the
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
 

=head2 run()

Call C<run()> on the test object to execute the query(ies) and evaluator.

If the database handle has RaiseError set
 
 $test->dbh->{RaiseError} = 1;

then query failures are indicated by 

 $test->result eq 'not ok'

and the database error in $test->comment.

=head2 Data methods

Data values are added in the evaluator method. Custom evaluators
(e.g., code refs) ideally should follow these conventions.

=over 

=item result

C<undef> if not run, 'ok' if success, 'not ok' if failure.

=item comment

Contains a comment, starting with '#'. Will contain a reason for failure on fail.

=item passed

TRUE if passed, FALSE if failed/not run.

=item date

Timestamp of test (set when run), in format C<YYYYMMDD.HH:MM.ZZZZ>.

=back

=head2 Getter/Setters

These properties may be set after construction.

=over

=item group() - Test group name

 $test->group('DR7.0-RC');

=item dbh() - L<DBD::Neo4p> database handle

 $dbh = DBI->connect(...);
 $dbh->{RaiseError} = 1;
 $test->dbh($dbh);

=item save_dir() - Directory for saving results

 $test->save_dir('testdir');

=item nosave() - Override saving query responses on failure/debug

 $test->nosave(1);

=back

=head1 SEE ALSO

L<Neo4j::TestBot::Data>

=head1 AUTHOR

 Mark A. Jensen
 FNLCR
 mark -dot- jensen -at- nih -dot- gov

=cut
