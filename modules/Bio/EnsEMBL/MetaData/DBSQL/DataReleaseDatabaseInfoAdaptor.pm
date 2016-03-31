
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

Bio::EnsEMBL::MetaData::DBSQL::DataReleaseDatabaseInfoAdaptor

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBSQL::DataReleaseDatabaseInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::MetaData::DataReleaseDatabaseInfo;
use List::MoreUtils qw(natatime);

=head1 METHODS
=cut

sub store {
  my ( $self, $data_release_database ) = @_;
  if ( !defined $data_release_database->dbID() ) {
    my $dbID = @{
      $self->dbc()->sql_helper()->execute_simple(
        -SQL =>
"select data_release_database_id from data_release_database where dbname=? and data_release_id=?",
        -PARAMS =>
          [ $data_release_database->dbname(), $data_release_database->dbID() ] )
    };

    if ( defined $dbID ) {
      $data_release_database->dbID($dbID);
      $data_release_database->adaptor($self);
    }
    if ( !defined $data_release_database->dbID() ) {
      $self->update($data_release_database);
    }
    else {
      $self->dbc()->sql_helper()->execute_update(
        -SQL =>
q/insert into data_release_database(data_release_id,type,division_id,dbname) values (?,?,?,?)/,
        -PARAMS => [ $data_release_database->release()->dbID(),
                     $data_release_database->type(),
                     $self->_get_division_id( $data_release_database->division()
                     ),
                     $data_release_database->dbname() ],
        -CALLBACK => sub {
          my ( $sth, $dbh, $rv ) = @_;
          $data_release_database->dbID( $dbh->{mysql_insertid} );
        } );
      $data_release_database->adaptor($self);
      $self->_store_cached_obj($data_release_database);
    }
    return;
  } ## end if ( !defined $data_release_database...)
} ## end sub store

sub update {
  my ( $self, $data_release_database ) = @_;
  if ( !defined $data_release_database->dbID() ) {
    croak "Cannot update an object that has not already been stored";
  }

  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
q/update data_release_database set data_release_id=?, type=?, division=?, dbname=? where data_release_database_id=?/,
    -PARAMS => [ $data_release_database->release()->dbID(),
                 $data_release_database->type(),
                 $self->_get_division_id( $data_release_database->division() ),
                 $data_release_database->dbname() ] );
  return;
}

sub fetch_databases {
  my ( $self, $release, $division ) = @_;

  my $sql =
q/select dbname,type,d.name from data_release_database join division d using (division_id) where data_release_id=?/;
  my $params = [ $release->dbID() ];
  if ( defined $division ) {
    $sql .= ' and (d.name=? or d.short_name=?)';
    $params = [ @$params, $division, $division ];
  }

  my $databases = [];

  $self->dbc()->sql_helper()->execute_no_return(
    -SQL      => $sql,
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      push @{$databases},
        Bio::EnsEMBL::MetaData::DataReleaseDatabaseInfo->new(
                                                           -RELEASE => $release,
                                                           -DBNAME  => $row[0],
                                                           -TYPE    => $row[1],
                                                           -DIVISION => $row[2]
        );
      return;
    },
    -PARAMS => $params );

  return $databases;
} ## end sub fetch_databases

=head2 _fetch_children
  Arg	     : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Fetch all children of specified genome info object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_children {
  my ( $self, $md ) = @_;
  return;
}

my $base_data_release_database_fetch_sql =
q/select data_release_database_id as dbID, data_release_id, type, division.name as division, dbname from data_release_database join division using (division_id)/;

sub _get_base_sql {
  return $base_data_release_database_fetch_sql;
}

sub _get_id_field {
  return 'data_release_database_id';
}

sub _get_obj_class {
  return 'Bio::EnsEMBL::MetaData::DataReleaseDatabaseInfo';
}

1;
