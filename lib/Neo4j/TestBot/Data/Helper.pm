package Neo4j::TestBot::Data::Helper;
use JSON::XS;
use REST::Neo4p::ParseStream;
use HOP::Stream qw/drop/;
use REST::Neo4p::Exceptions;
use base Exporter;
use strict;
use warnings;

# This is something that REST::Neo4p::Query should be able to do by itself.
# As it is, ach, what a kludge.
# reset_query($q) allows the parser to reparse the result tempfile without performing the query again.
# can do $q->fetch, etc. starting from the first result row.

our $BUFSIZE = 50000;
our @EXPORT = qw/reset_query/;

# reset_query($rest_neo4p_query)
sub reset_query {
  my $self = shift;
  my $jsonr = JSON::XS->new;
  my ($buf,$res,$str,$rowstr,$obj);
  my $row_count;
  eval { # capture j_parse errors
    $self->tmpf->seek(0,0); # the reset
    $self->tmpf->read($buf, $BUFSIZE);
    $jsonr->incr_parse($buf);
    $res = j_parse($jsonr);
    die 'j_parse: No text to parse' unless $res;
    die 'j_parse: JSON is not a query response' unless $res->[0] =~ /QUERY/;
    $obj = drop($str = $res->[1]->());
    die 'j_parse: columns key not present' unless $obj && ($obj->[0] eq 'columns');
    $self->{NAME} = $obj->[1];
    $self->{NUM_OF_FIELDS} = scalar @{$obj->[1]};
    $obj = drop($str);
    die 'j_parse: data key not present' unless $obj->[0] eq 'data';
    $rowstr = $obj->[1]->();
    # query iterator
    $self->{_iterator} =  sub {
      return unless defined $self->tmpf;
      my $row;
      my $item;
      $item = drop($rowstr);
      unless ($item) {
	undef $rowstr;
	return;
      }
      $row = $item->[1];
      if (ref $row) {
	return $self->_process_row($row);
      }
      else {
	my $ret;
	eval {
	  if ($row eq 'PENDING') {
	    if ($self->tmpf->read($buf, $BUFSIZE)) {
	      $jsonr->incr_parse($buf);
	      $ret = $self->{_iterator}->();
	    }
	    else {
	      $item = drop($rowstr);
	      $ret = $self->_process_row($item->[1]);
	    }
	    
	  }
	  else {
	    die "j_parse: barf(qry)"
	  }
	};
	if (my $e = Exception::Class->caught()) {
	  if ($e =~ /j_parse|json/i) {
	    $e = REST::Neo4p::StreamException->new(message => $e);
	    $self->{_error} = $e;
	    $e->throw if $self->{RaiseError};
	    return;
	  }
	  else {
	    die $e;
	  }
	}
	return $ret;
      }
    };
  };
  if (my $e = Exception::Class->caught()) {
    if ($e =~ /j_parse|json/) {
      $e = REST::Neo4p::StreamException->new(message => $e);
      $self->{_error} = $e;
      $e->throw;
      return;
    }
    else {
      $e->throw;
    }
  }
  return 1;
}

