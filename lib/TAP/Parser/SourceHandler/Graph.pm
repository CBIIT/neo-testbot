package TAP::Parser::SourceHandler::Graph;
use lib '../../../../lib';
use base 'TAP::Parser::SourceHandler';
use TAP::Parser::IteratorFactory;
use Try::Tiny;
use File::Spec;
use YAML qw/LoadFile/;
use Neo4j::TestBot qw/test cypher ptn/;
use TAP::Parser::Iterator::Array;
use Log::Log4perl::Level;

use strict;

TAP::Parser::IteratorFactory->register_handler( __PACKAGE__ );

sub can_handle {
  my ($class, $src) = @_;
  my $meta = $src->meta;
  my $config = $src->config_for( $class );

  if (my $file = $meta->{file}) {
    return 0.0 unless $file->{exists};
    return 1.0 if $file->{lc_ext} =~ /ya?ml$/i; # yaml
  }
  elsif ($meta->{hash}) {
    return 0.9 if defined $src->raw->{tests} && (ref($src->raw->{tests}) eq 'ARRAY');
  }
  else {
    return 0.0;
  }
}

# actually - maybe all that needs to be done is to create and run the Unit tests here, put their results in an array
# and return a TAP::Parser::Iterator::Array....
# -or- have Neo4j::TestBot::Data run the Unit tests, but return the TAP in an array, rather than print it; capture the array
# and return iterator.###
# BUT -- would be nicer to have an iterator that is non-blocking, so harness can report more in real time (feat)

sub make_iterator {
  my ($class, $src) = @_;
  my $suite;
  my $meta = $src->meta;
  if ($meta->{file}) {
    my $fn = File::Spec->catfile($meta->{file}{dir}, $meta->{file}{basename});
    $suite = LoadFile($fn) or $class->_croak("Problem with $fn: $!");
  }
  elsif ($meta->{hash}) {
    $suite = $src->raw
  }
  else {
    $class->croak("Don't understand the test spec.");
  }
  $class->_check_suite($suite) or $class->_croak("Can't proceed: errors in test suite '$$meta{file}'");
  #  return TAP::Parser::Iterator::Array->new( $class->_run_suite($suite) );
  return TAP::Parser::Iterator::Stream->new( $class->_run_suite($suite) );
}

sub _check_suite {
  my $class = shift;
  my ($suite) = @_;
  # check that required fields are present
  unless (defined $suite->{db_host} && defined $suite->{db_port}) {
    $class->_carp("db_host and db_port required");
    return;
  }
  unless (defined $suite->{tests} and ref $suite->{tests} eq 'ARRAY') {
    $class->_carp("No tests defined");
    return;
  }
  for my $t (@{$suite->{tests}}) {
    if ( defined $t->{query} and ref($t->{query}) ) {
      $class->_carp("Value for 'query' field should be a string; maybe you want 'queries' for multiple queries?");
      return;
    }
    if ( defined $t->{queries} and !ref($t->{queries}) ) {
      $class->_carp("Value for 'queries' field should be an array of queries; maybe you want 'query' for a single query?");
      return;
    }
  }
  return 1; 
}

sub _run_suite {
  my $class = shift;
  my ($suite) = (@_);

  # process configuration
  my $tests = delete $$suite{tests};
  my ($db_host,$db_port) = delete @$suite{qw/db_host db_port/};
  pipe(my $r, my $w);
  $r->autoflush(1);
  $w->autoflush(1);
  my $pid = fork() // $class->_croak("Can't fork test runner: $!");
  if ($pid) {
    close $w;
    return $r;
  }
  else {
    my $dbh = DBI->connect("dbi:Neo4p:host=$db_host;port=$db_port");
    $dbh->{RaiseError} = 1;
    my %dargs = ( dbh => $dbh,
		  output => $w,
		  %$suite );
    my $g = Neo4j::TestBot::Data->new(%dargs);
    my @tests = $class->_create_units($tests);
    $g->runtests(@tests);
#    $dbh->disconnect;
    exit(0);
  }
}

sub _create_units {
  # convert test hashes to Neo4j::TestBot::Data::Unit objects
  # including evalling cypher::abstract representations
  my $class = shift;
  my @tests = @{$_[0]};
  my @units;
 TEST:
  foreach my $t (@tests) {
    my $qry = delete $$t{query};
    $qry = [$qry] if defined $qry;
    $qry or $qry = delete $$t{queries};
    foreach (@$qry) {
      if (/^cypher/) {
	unless ($class->_safe_query($_)) {
	  $class->_carp("Unsafe query code: [$_]");
	  next TEST;
	}
	$_ = eval;
	if ($@) {
	  $class->_croak("Query code failed compilation: $@");
	}
	$_ = "$_";
      }
    }
    if (@$qry == 1) {
      $t->{query} = $qry->[0];
    }
    else {
      $t->{queries} = $qry;
    }
    push @units, test(%$t);
  }
  return @units;
}

sub _safe_query {
  # a little taint checking
  my $class = shift;
  my ($q) = @_;
  return unless (
    $q =~ /^cypher/ and
      $q !~ /\beval\b/ and
      $q !~ /\bsub\s*{\b/ and
      $q !~ /;/
   );
  return 1;
}

sub _carp {
  my $proto = shift;
  require Carp;
  Carp::carp(@_);
  return;
}
    

1;
