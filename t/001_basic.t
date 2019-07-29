use Test::More;
use lib '../lib';
use strict;
use warnings;

use_ok('Neo4j::TestBot');

isa_ok(Neo4j::TestBot::Data->new(), 'Neo4j::TestBot::Data');
isa_ok(Neo4j::TestBot::Data::Unit->new(name=>'try'), 'Neo4j::TestBot::Data::Unit');

done_testing;
