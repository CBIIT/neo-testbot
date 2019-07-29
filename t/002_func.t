use Test::More;
use Test::Exception;
use lib '../lib';
use DBI;
use Neo4j::TestBot qw/test/;
use strict;
use warnings;

my $init =<<LOGGER;
 log4perl.rootLogger=FATAL,A
 log4perl.appender.A=Log::Log4perl::Appender::String
 log4perl.appender.A.name=test
 log4perl.appender.A.layout=Log::Log4perl::Layout::SimpleLayout
LOGGER

Log::Log4perl::init(\$init);
isa_ok(test(name=>'try'), 'Neo4j::TestBot::Data::Unit');
dies_ok { test(); } 'obj without a name dies';
my $t = test( name => 'The Test', desc => "this is a test");
is $t->name, 'The Test', 'accessor';
is $t->desc, 'this is a test', 'accessor';
dies_ok { test( name => 'try',evaluate => ['not a code ref']) } 'bad evaluate arg; not string or coderef';
dies_ok { test( name => 'try',evaluate => 'slurps_ok' ) } 'bad evaluate arg; unknown method';
lives_ok { test( name => 'try',evaluate => sub { 1 } ) } 'good evaluate arg; a coderef';
lives_ok { test( name => 'try', evaluate => 'returns_n_rows' ) } 'good evaluate arg; known method';
$t = test( name => 'The Test', evaluate => sub { shift->{result} = 'ok' } );
$t->run;
ok $t->passed, 'coderef to evaluate';
like $t->date, qr/^[0-9]{8}.[0-9]{2}:[0-9]{2}\..{5}$/, 'got date';


done_testing;

