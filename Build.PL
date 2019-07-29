use Module::Build;
use strict;
use warnings;
my $build = Module::Build->new(
  dist_name => 'Neo4j::TestBot',
  dist_version_from => 'lib/Neo4j/TestBot.pm',
  dist_abstract => 'Automated tests on graph metadata',
  perl => 5.020,
  configure_requires => {
    'Module::Build' => 0,
  },
  build_requires => {
    DBI => 0,
  },
  requires => {
    JSON => 0,
    'DBI' => 0,
    'DBD::Neo4p' => 0,
    'Try::Tiny' => 0,
    'Log::Log4perl' => 0,
    'Neo4j::Cypher::Abstract' => 0,
    'TAP::Harness' => 3.39,
  },
  meta_merge => {
    resources => {
      bugtracker => 'https://github.com/CBIIT/neo-testbot/issues',
      repository => 'https://github.com/CBIIT/neo-testbot.git'
     }
   },
 );

$build->create_build_script;
