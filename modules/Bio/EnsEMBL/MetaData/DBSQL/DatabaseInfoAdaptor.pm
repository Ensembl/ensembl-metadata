
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

package Bio::EnsEMBL::MetaData::DBSQL::DatabaseInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::MetaData::DatabaseInfo;
use List::MoreUtils qw(natatime);

=head1 METHODS
=cut

sub store {
  my ( $self, $database ) = @_;
  my $ref = ref( $database->subject() );
  $ref =~ s/.*:([^:]+)$/store_$1/;
  $self->$ref($database);
  return;
}

sub update {
  my ( $self, $database ) = @_;
  my $ref = ref( $database->subject() );
  $ref =~ s/.*:([^:]+)$/update_$1/;
  $self->$ref($database);
  return;
}

sub store_DataReleaseInfo {
  my ( $self, $data_release_database ) = @_;
  if ( !defined $data_release_database->dbID() ) {
    my $dbID = @{
      $self->dbc()->sql_helper()->execute_simple(
        -SQL => q/select data_release_database_id from data_release_database 
where dbname=? and data_release_id=?/,
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
q/insert into data_release_database(data_release_id,type,division_id,dbname) 
values (?,?,?,?)/,
        -PARAMS => [ $data_release_database->subject()->dbID(),
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
  } ## end if ( !defined $data_release_database...)
  return;
} ## end sub store_DataReleaseInfo

sub update_DataReleaseInfo {
  my ( $self, $database ) = @_;
  if ( !defined $database->dbID() ) {
    croak "Cannot update an object that has not already been stored";
  }

  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
q/update data_release_database set data_release_id=?, type=?, division=?, dbname=? 
where data_release_database_id=?/,
    -PARAMS => [ $database->subject()->dbID(),
                 $database->type(),
                 $self->_get_division_id( $database->division() ),
                 $database->dbname() ] );
  return;
}

sub store_GenomeInfo {
  my ( $self, $genome_database ) = @_;
  if ( !defined $genome_database->dbID() ) {
    my $dbID = @{
      $self->dbc()->sql_helper()->execute_simple(
        -SQL => q/select genome_database_id from genome_database 
where dbname=? and genome_id=?/,
        -PARAMS => [ $genome_database->dbname(), $genome_database->dbID() ] ) };

    if ( defined $dbID ) {
      $genome_database->dbID($dbID);
      $genome_database->adaptor($self);
    }
    if ( !defined $genome_database->dbID() ) {
      $self->update($genome_database);
    }
    else {
      $self->dbc()->sql_helper()->execute_update(
        -SQL => q/insert into genome_database(genome_id,type,species_id,dbname) 
values (?,?,?,?)/,
        -PARAMS => [ $genome_database->subject()->dbID(),
                     $genome_database->type(),
                     ($genome_database->species_id()||1),
                     $genome_database->dbname() ],
        -CALLBACK => sub {
          my ( $sth, $dbh, $rv ) = @_;
          $genome_database->dbID( $dbh->{mysql_insertid} );
        } );
      $genome_database->adaptor($self);
      $self->_store_cached_obj($genome_database);
    }
  } ## end if ( !defined $genome_database...)
  return;
} ## end sub store_GenomeInfo

sub update_GenomeInfo {
  my ( $self, $database ) = @_;
  if ( !defined $database->dbID() ) {
    croak "Cannot update an object that has not already been stored";
  }

  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
      q/update genome_database set genome_id=?, type=?, species_id=?, dbname=? 
where genome_database_id=?/,
    -PARAMS => [ $database->subject()->dbID(), $database->type(),
                 ($database->species_id()||1),      $database->dbname() ] );
  return;
}

sub fetch_databases {
  my ( $self, $subject, $division ) = @_;
  my $ref = ref($subject);
  $ref =~ s/.*:([^:]+)$/fetch_databases_$1/;
  return $self->$ref($subject);
}

sub fetch_databases_DataReleaseInfo {
  my ( $self, $release, $division ) = @_;
  my $sql = q/select dbname,type,d.name from data_release_database 
join division d using (division_id) where data_release_id=?/;
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
        Bio::EnsEMBL::MetaData::DatabaseInfo->new( -SUBJECT  => $release,
                                                   -DBNAME   => $row[0],
                                                   -TYPE     => $row[1],
                                                   -DIVISION => $row[2] );
      return;
    },
    -PARAMS => $params );

  return $databases;
} ## end sub fetch_databases_DataReleaseInfo

sub fetch_databases_GenomeInfo {

  my ( $self, $genome ) = @_;
  my $sql = q/select genome_database_id, dbname, type, species_id from genome_database 
where genome_id=?/;
  my $params    = [ $genome->dbID() ];
  my $databases = [];

  $self->dbc()->sql_helper()->execute_no_return(
    -SQL      => $sql,
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      push @{$databases},
        Bio::EnsEMBL::MetaData::DatabaseInfo->new( -SUBJECT    => $genome,
                                                   -DBID     => $row[0],
                                                   -DBNAME       => $row[1],
                                                   -TYPE => $row[2],
                                                   -SPECIES_ID => $row[3] );
      return;
    },
    -PARAMS => $params );

  return $databases;
}

1;
