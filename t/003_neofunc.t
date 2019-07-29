use Test::More;
use Test::Exception;
use lib '../lib';
use Try::Tiny;
use DBI;
use Neo4j::TestBot qw/test/;
use strict;
use warnings;

my $host = $ENV{NEO4J_HOST} || 'localhost';
my $port = $ENV{NEO4J_PORT} || 7474;
my $dbh;
my $init =<<LOGGER;
 log4perl.rootLogger=FATAL,A
 log4perl.appender.A=Log::Log4perl::Appender::String
 log4perl.appender.A.name=test
 log4perl.appender.A.layout=Log::Log4perl::Layout::SimpleLayout
LOGGER
Log::Log4perl::init(\$init);

try {
  $dbh = DBI->connect("dbi:Neo4p:host=$host;port=$port","","",{RaiseError=>1});
} catch {
  plan skip_all => "Problems connecting to Neo4j at http://$host:$port (1)";
};

unless ($dbh->ping) {
  plan skip_all => "Problems connecting to Neo4j at http://$host:$port (2)";
}

my $test = test( name=>'Test', query=>'match(a:Glarb) return(a)',
		 dbh => $dbh);

is $test->run, 'ok', 'default (return_no_rows)';

done_testing;

END {
  $dbh->disconnect if defined $dbh;
}
