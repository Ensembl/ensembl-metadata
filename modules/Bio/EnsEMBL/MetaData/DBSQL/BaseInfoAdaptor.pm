
=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod

=head1 NAME

Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor

=head1 DESCRIPTION

Base adaptor for storing and retrieving objects from MySQL genome_metadata database

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor;

use strict;
use warnings;
use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Data::Dumper;
use List::MoreUtils qw/natatime/;

use base qw/Bio::EnsEMBL::DBSQL::BaseAdaptor/;

=head1 METHODS
=head2 fetch_all
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all {
  my ( $self, $keen ) = @_;
  return $self->_fetch_generic_with_args( {}, $keen );
}

=head2 fetch_by_dbID
  Arg	     : ID of genome info
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified ID
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub fetch_by_dbID {
  my ( $self, $id, $keen ) = @_;
  return
    $self->_first_element( $self->_fetch_generic_with_args(
                                         { $self->_get_id_field(), $id }
                           ),
                           $keen );
}

=head2 fetch_by_dbIDs
  Arg	     : IDs of genome info
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified ID
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub fetch_by_dbIDs {
  my ( $self, $ids, $keen ) = @_;
  my @genomes = ();
  my $it = natatime 1000, @{$ids};
  while ( my @vals = $it->() ) {
    my $sql =
      $self->_get_base_sql() . ' where ' . $self->_get_id_field() .
      ' in (' .
      join( ',', @vals ) . ')';
    @genomes = ( @genomes, @{ $self->_fetch_generic( $sql, [] ) } );
  }
  return \@genomes;
}

sub _get_base_sql {
  throw("Method not implemented in base class");
}

sub _get_id_field {
  throw("Method not implemented in base class");
}

sub _get_obj_class {
  throw("Method not implemented in base class");
}

=head2 _fetch_generic_with_args
  Arg	     : hashref of arguments by column
  Arg        : (optional) if set to 1, all children will be fetched
  Description: Instantiate a GenomeInfo from the database using a 
               generic method, with the supplied arguments
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_generic_with_args {
  my ( $self, $args, $type, $keen ) = @_;
  my ( $sql, $params ) =
    $self->_args_to_sql( $self->_get_base_sql(), $args );
  my $info =
    $self->_fetch_generic( $sql, $params, $self->_get_obj_class(),
                           $keen );
  return $info;
}

sub _fetch_children {
  my ( $self, $i ) = @_;
  # do nothing
  return;
}

sub _args_to_sql {
  my ( $self, $sql_in, $args ) = @_;
  my $sql    = $sql_in;
  my $params = [];
  my $clause = '';
  while ( my ( $k, $v ) = each %$args ) {
    if ( $clause ne '' ) {
      $clause .= ' AND ';
    }
    if ( ref($v) eq 'ARRAY' ) {
      $clause .= "$k in (" . join( ',', map { '?' } @$v ) . ")";
      $params = [ @$params, @$v ];
    }
    else {
      $clause .= "$k = ?";
      push @$params, $v;
    }
  }
  if ( $clause ne '' ) {
    $sql .= ' where ' . $clause;
  }
  return ( $sql, $params );
}

=head2 _fetch_generic
  Arg	     : SQL to use to fetch object
  Arg	     : arrayref of bind parameters
  Arg        : (optional) if set to 1, all children will be fetched
  Description: Instantiate a GenomeInfo from the database using the specified SQL
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_generic {
  my ( $self, $sql, $params, $type, $keen ) = @_;
  if ( !defined $type ) {
    $type = $self->_get_obj_class();
  }
  my $mds = $self->{dbc}->sql_helper()->execute(
    -SQL          => $sql,
    -USE_HASHREFS => 1,
    -CALLBACK     => sub {
      my $row = shift @_;
      my $md = $self->_get_cached_obj( $type, $row->{dbID} );
      if ( !defined $md ) {
        $md = bless $row, $type;
        $md->adaptor($self);
        $self->_store_cached_obj($md);
      }
      return $md;
    },
    -PARAMS => $params );
  if ( defined $keen && $keen == 1 ) {
    for my $md ( @{$mds} ) {
      $self->_fetch_children($md);
    }
  }
  return $mds;
} ## end sub _fetch_generic

=head2 _cache
  Arg	     : type of object for cache
  Description: Return internal cache for given type
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _cache {
  my ( $self, $type ) = @_;
  if ( !defined $self->{cache} || !defined $self->{cache}{$type} ) {
    $self->{cache}{$type} = {};
  }
  return $self->{cache}{$type};
}

=head2 _clear_cache
  Arg	     : (optional) type of object to clear
  Description: Clear internal cache (optionally just one type)
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _clear_cache {
  my ( $self, $type ) = @_;
  if ( defined $type ) {
    $self->{cache}{$type} = {};
  }
  else {
    $self->{cache} = {};
  }
  return;
}

=head2 _get_cached_obj
  Arg	     : type of object to retrieve
  Arg	     : ID of object to retrieve
  Description: Retrieve object from internal cache
  Returntype : object
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _get_cached_obj {
  my ( $self, $type, $id ) = @_;
  return $self->_cache($type)->{$id};
}

=head2 _store_cached_obj
  Arg	     : type of object to store
  Arg	     : object to store
  Description: Store object in internal cache
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_cached_obj {
  my ( $self, $obj ) = @_;
  my $type = ref $obj;
  $self->_cache($type)->{ $obj->dbID() } = $obj;
  return;
}

=head2 _first_element
  Arg	     : arrayref
  Description: Utility method to return the first element in a list, undef if empty
  Returntype : arrayref element
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _first_element {
  my ( $self, $arr ) = @_;
  if ( defined $arr && scalar(@$arr) > 0 ) {
    return $arr->[0];
  }
  else {
    return undef;
  }
}

1;
