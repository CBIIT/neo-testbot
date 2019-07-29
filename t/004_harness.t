use Test::More;
use TAP::Harness;
use Try::Tiny;
use lib '../lib';
use strict;

my $t = (-d 't' ? 't' : '.');

open my $bitbucket, ">bitbucket.out" or die "bitbucket: $!";
ok my $harness = TAP::Harness->new({
  verbosity => 1,
  stdout => $bitbucket,
  sources => {
    Graph => {},
    }
 }), 'harness loads with source Graph';

try {
  ok ($harness->runtests("$t/samples/test1.yaml"), 'run test1: pass, TAP level');
} catch {
  diag 'Problems connecting to Neo4j';
  done_testing;
  exit(0);
};
ok my $logexists = -e 'test1.log', 'log file created';

SKIP : {
  skip "log file not created", 1 unless $logexists;
  open my $l, "test1.log" or die "test1.log : $!";
  undef $/;
  $_ = <$l>;
  like $_, qr/\[TAP\]/, "log contains [TAP] lines";
  unlike $_, qr/\[DEBUG\]/, "but log contains no [DEBUG] lines";
  close($l);
  unlink 'test1.log';
}

ok $harness->runtests("$t/samples/test2.yaml"), 'run test2: fail, DEBUG level';
ok my $logexists = -e 'test2.log', 'log file created';

SKIP : {
  skip "log file not created", 1 unless $logexists;
  open my $l, "test2.log" or die "test2.log : $!";
  undef $/;
  $_ = <$l>;
  like $_, qr/\[TAP\]/, "log contains [TAP] lines";
  like $_, qr/\[DEBUG\]/, "log also contains [DEBUG] lines";
  like $_, qr/\[TAP\].*ok [0-9][^#]+# SKIP/, "TAP contains SKIP";
  like $_, qr/\[TAP\].*ok [0-9][^#]+# TODO/, "TAP contains TODO";
  close($l);
  unlink 'test2.log';
  opendir(my $d,'./demo');
  my @f = readdir $d;
  is grep(/\.json/, @f),2, 'json created';
  unlink glob('demo/*.json');
}

done_testing;

END {
  # cleanup
  no warnings;
  unlink 'bitbucket.out';
}
