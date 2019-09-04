package Neo4j::TestBot;
use lib '../../lib';
use Neo4j::TestBot::Data;
use Neo4j::TestBot::Data::Unit qw/test cypher ptn/;
use base 'Exporter';
use strict;

our $VERSION = '0.1000';
our @EXPORT_OK=qw/test cypher ptn/;

=head1 NAME

Neo4j::TestBot::Data - Automated tests for graph metadata

=head1 SYNOPSIS

 # install
 $ git clone https://github.com/CBIIT/neo-testbot.git
 $ cd neo-testbot
 $ perl Build.PL
 $ ./Build installdeps
 $ ./Build test
 $ ./Build install

 # run tests
 $ prove --source Graph t/my_data_tests.yaml

=head1 DESCRIPTION

Neo4j::TestBot::Data provides a framework for automated testing of graph
metadata. Tests are based on specifying Neo4j queries along with
expected output from those queries. When the actual queries returns
the expected output, the test passes; otherwise, it fails.

Features:

=over

=item * Neo4j::TestBot::Data allows tests to be specified and annotated in YAML files;
no coding is required.

=item * Neo4j::TestBot::Data is compatible with Perl's L<TAP::Harness> framework; tests
can be executed with the built-in L<prove|App::Prove> command, and can
benefit from its automatic test summarizing, aggregation, and
parallelization capabilities.

=item * Neo4j::TestBot::Data can will also log internal events fairly extensively
if desired, creating a log file separate from the test output. The log
can be set to fire according to desired level.

=item * When tests fail, the output of the query and test metadata is
automatically saved in a JSON format. The QA engineer can review the
data without having to rerun the query.

=item * Individual tests can be written to compare the results of more than one query.

=back

=head1 YAML Format for Test Suites

A suite of tests to run together can be specified in a YAML file. Top
level keys are for configuration, and the C<tests> key points to an
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
       fails won't count again you
     todo : Get a round tuit

=head1 Evaluators

The value of the C<evaluate> key specifies the method to use to
evaluate the test. Some evaluators require an C<expect> key to specify
the pass state.

=over

=item * returns_no_rows

=item * returns_some_rows

=item * returns_n_rows

C<expect> should be the integer number of rows expected.

=item * returns_count_n

Specify a query that returns a single row with a single value
(e.g., C<... return count(n)>). 

C<expect> should be the value expected.

=item * returns_value_for_field

The query is executed and a single returned row is analyzed. Test outcome depends on the value of the C<expect> paramenter:

 expect => $value

Test succeeds if the first value of the returned row equals C<$value>.

 expect => [$field => $value]

Test succeeds if the row value of field C<$field> equals C<$value>

 expect => { $field1 => $value1, $field2 => $value2, ... }

Test succeeds if for every C<$field1>, C<$field2>, ..., the returned values equal C<$value1>, C<$value2>, ... respectively.

=item * returns_same_n_rows

Specify two or more queries; each should return the same number of rows. 

=item * returns_same_counts

Specify two or more queries that result in a single row with single
value (e.g., C<...return count(f)>). Test succeeds if that value is
identical for every query.

=back

=head1 SEE ALSO

L<Neo4j::TestBot::Data|lib/Neo4j/TestBot/README.Data.md>, L<Neo4j::TestBot::Data::Unit|lib/Neo4j/TestBot/Data/README.Unit.md>, L<TAP::Harness>, L<App::Prove>.

=head1 AUTHOR

 Mark A. Jensen
 FNLCR
 mark -dot- jensen -at- nih -dot- gov

=cut

1;

package Neo4j::TestBot::Data::Unit;
use Set::Scalar;
use strict;

our $logger;
# put all the test evaluation methods here

# return ok if query returned no rows
sub returns_no_rows {
  my $self = shift;
  $logger->debug("Enter returns_no_rows for unit test '".$self->name."'");
  my $q = $self->query;
  unless (exists $self->{sth}{"$q"}) {
    $logger->logcroak("No statement handle for query '$q' in returns_no_rows for test '".$self->name."'");
  }

  if (!defined($self->{sth}{"$q"}->fetch)) {
    $self->{result} = 'ok';
  }
  else {
    $self->{comment} = "# --- returned rows";
    $self->{result} = 'not ok';
  }
}

sub returns_some_rows {
  my $self = shift;
  $logger->debug("Enter returns_some_rows for unit test '".$self->name."'");
  my $q = $self->query;
  unless (exists $self->{sth}{"$q"}) {
    $logger->logcroak("No statement handle for query '$q' in returns_no_rows for test '".$self->name."'");
  }

  if (defined($self->{sth}{"$q"}->fetch)) {
    $self->{result} = 'ok';
  }
  else {
    $self->{comment} = "# --- returned no rows";
    $self->{result} = 'not ok';
  }
}

sub returns_count_n {
  my $self = shift;
  $logger->debug("Enter returns_count_n for unit test '".$self->name."'");
  my $q = $self->query;
  unless (exists $self->{sth}{"$q"}) {
    $logger->logcroak("No statement handle for query '$q' in returns_count_n for test '".$self->name."'");
  }
  unless (defined $self->expect or !looks_like_number($self->expect) ) {
    $logger->logcroak("returns_count_n requires expected count value in expect parameter");
  }
  # assume that one row is returned with first value an integer (e.g., count(n) )
  my $row = $self->{sth}{"$q"}->fetch;
  if (!defined $row) {
    $self->{comment} = '# *** Query returned no rows ';
    return $self->{result} = 'not ok';
  }
  if ($self->expect == $row->[0]) {
    return $self->{result} = 'ok';
  }
  else {
    $self->{comment} = "# --- wanted count value ".$self->expect.", returned $$row[0]";
    return $self->{result} = 'not ok'
  }
}


# return ok if query returned {expect} number of rows
sub returns_n_rows {
  my $self = shift;
  $logger->debug("Enter returns_n_rows for unit test '".$self->name."'");
  my $q = $self->query;
  unless (exists $self->{sth}{"$q"}) {
    $logger->logcroak("No statement handle for query '$q' in returns_n_rows for test '".$self->name."'");
  }
  my $got = $self->{sth}{"$q"}->{neo_rows};
  if ($got == $self->expect) {
    $self->{result} = 'ok';
  }
  else {
    $self->{comment} = "# --- wanted ".$self->expect." rows, got $got";
    $self->{result} = 'not ok';
  }
}

sub returns_same_n_rows {
  my $self = shift;
  $logger->debug("Enter returns_same_n_rows for unit test '".$self->name."'");
  my @counts;
  for my $q ($self->queries) {
    unless (exists $self->{sth}{"$q"}) {
      $logger->logcroak("No statement handle for query '$q' in returns_n_rows for test '".$self->name."'");
    }
    push @counts, $self->{sth}{"$q"}->{neo_rows};
  }
  my $s = Set::Scalar->new(@counts);
  if ($s->size == 1) {
      $self->{result} = 'ok';
  }
  else {
    $self->{comment} = "# --- got differing counts ".join(',',@counts);
    $self->{result} = 'not ok';
  }
}

sub returns_same_counts {
  my $self = shift;
  $logger->debug("Enter returns_same_counts for unit test '".$self->name."'");
  my @counts;
  for my $q ($self->queries) {
    unless (exists $self->{sth}{"$q"}) {
      $logger->logcroak("No statement handle for query '$q' in returns_same_counts for test '".$self->name."'");
    }
    # assume that one row is returned with first value an integer (e.g., count(n) )
    my $row = $self->{sth}{"$q"}->fetch;
    push @counts, $row->[0];
  }
  my $s = Set::Scalar->new(@counts);
  if ($s->size == 1) {
      $self->{result} = 'ok';
  }
  else {
    $self->{comment} = "# --- got differing counts ".join(',',@counts);
    $self->{result} = 'not ok';
  }
}

# return ok if query returned given 'value':
# expect a single row returned - if only one field (like for count(a)), check for equality
# if more than one field, have 'field.name' => $n
# {expect} is scalar - compare that value with the first value in the row
# {expect} is array - assume [ $field => $value ] and compare $row{$field} with $value
# {expect} is hash - assume { $fld1 => $val1, $fld2 => $val2, ... } and do analogous comparisons (fail fast)

sub returns_value_for_field {
  my $self = shift;
  $logger->debug("Enter returns_value_for_field for unit test '".$self->name."'");  
  my $q = $self->query;
  return unless exists $self->{sth}{"$q"};
  unless (exists $self->{sth}{"$q"}) {
    $logger->logcroak("No statement handle for query '$q' in returns_value_for_field for test '".$self->name."'");
  }

  my @row = @{$self->{sth}{"$q"}->fetch};
  if (!ref($self->expect)) {
    # scalar expected compare to first value in row
    if (_eq($row[0], $self->expect)) {
      $self->{result} = 'ok';
    }
    else {
      $self->{comment} = "# --- wanted ".$self->expect.", got "._str_or_undef($row[0]);
      $self->{result} = 'not ok';
    }
  }
  elsif (ref($self->expect) eq 'ARRAY') {
    my %got;
    my ($fld, $exp) = @{$self->expect};
    #    @got{@{$self->{row_names}{$q}}} = @row;
    @got{ @{$self->{sth}{"$q"}->{NAME}} } = @row;
    if (_eq($got{$fld},$exp)) {
      $self->{result} = 'ok';
    }
    else {
      $self->{comment} = "# --- expected ".$self->expect->[1]." for field ".$self->expect->[0].", got "._str_or_undef($got{$fld});
      $self->{result} = 'not ok';
    }
  }
  elsif (ref($self->expect) eq 'HASH') {
    my %got;
    @got{@{$self->{sth}{"$q"}->{NAME}}} = @row;
    $self->{result} = 'ok';
    while ( my ($fld, $exp) = each %{$self->expect} ) {
      unless (_eq($got{$fld},$exp)) {
	$self->{comment} = "# --- expected '$exp' for field $fld, got '"._str_or_undef($got{$fld})."'";
	$self->{result} = 'not ok';
	last;
      }
    }
  }
  else {
    $logger->logcroak("In returns_value_for_field, can't handle expect ref to ",ref $self->expect);
  }
  
  return $self->{result};
}

sub _eq {
  return unless defined $_[0] && defined $_[1];
  return ($_[0] == $_[1]) if (looks_like_number $_[1]);
  return ($_[0] eq $_[1]);
}

sub _str_or_undef {
  return '<undef>' unless defined $_[0];
  return "$_[0]";
}
1;
