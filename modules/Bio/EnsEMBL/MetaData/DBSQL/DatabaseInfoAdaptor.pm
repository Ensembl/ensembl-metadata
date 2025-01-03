
=head1 LICENSE

Copyright [1999-2025] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::DBSQL::DatabaseInfoAdaptor

=head1 SYNOPSIS

# metadata_db is an instance of MetaDataDBAdaptor
my $adaptor = $metadata_db->get_DatabaseInfoAdaptor();
$adaptor->fetch_databases($info);

=head1 DESCRIPTION

Adaptor to handle DatabaseInfo objects associated with GenomeInfo or DataReleaseInfo objects.

Uses delegate pattern to handle objects differently according to their subject objects.

=head1 AUTHOR

Dan Staines

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::DatabaseInfo
Bio::EnsEMBL::MetaData::DataReleaseInfo
Bio::EnsEMBL::MetaData::GenomeInfo

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
=head2 clear_genome_databases
  Arg        : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Clear databases for the supplied genome
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub clear_genome_databases {
  my ( $self, $genome ) = @_;
  $self->dbc()->sql_helper()->execute_update(-SQL=>q/delete from genome_database where genome_id=?/,
  -PARAMS=>[$genome->dbID()]);
  return;
}

=head1 METHODS
=head2 clear_genome_database
  Arg        : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Clear a genome associated database for the supplied genome and database type
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub clear_genome_database {
  my ( $self, $genome, $database ) = @_;
  $self->dbc()->sql_helper()->execute_update(-SQL=>q/delete from genome_database where genome_id=? and type=? and species_id=?/,
  -PARAMS=>[$genome->dbID(),$database->type(),$database->species_id()]);
  return;
}

=head2 clear_release_databases
  Arg        : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Description: Clear databases for the supplied release
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub clear_release_databases {
  my ( $self, $release ) = @_;
  $self->dbc()->sql_helper()->execute_update(-SQL=>q/delete from data_release_database  where data_release_id=?/,
  -PARAMS=>[$release->dbID()]);
  return;
}

=head2 clear_current_release
  Arg        : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Description: Clear current release flag for the supplied release
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub clear_current_release {
  my ( $self, $release ) = @_;
  $self->dbc()->sql_helper()->execute_update(-SQL=>q/update data_release set is_current=? where data_release_id=?/,
  -PARAMS=>[0,$release->dbID()]);
  return;
}



=head2 store
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Description: Store the supplied object
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub store {
  my ( $self, $database ) = @_;
  # delegate to appropriate method for the subject
  my $ref = ref( $database->subject() );
  $ref =~ s/.*:([^:]+)$/store_$1/;
  $self->$ref($database);
  return;
}

=head2 update
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Description: Update the supplied object (must be previously stored)
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub update {
  my ( $self, $database ) = @_;
  # delegate to appropriate method for the subject
  my $ref = ref( $database->subject() );
  $ref =~ s/.*:([^:]+)$/update_$1/;
  $self->$ref($database);
  return;
}

=head2 fetch_databases
  Arg        : Bio::EnsEMBL::MetaData::DataReleaseInfo 
               or Bio::EnsEMBL::MetaData::GenomeInfo
  Arg        : String - Optional division
  Description: Find the databases associated with the supplied object
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::DatabaseInfo 
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub fetch_databases {
  my ( $self, $subject, $division ) = @_;
  # delegate to appropriate method for the subject
  my $ref = ref($subject);
  $ref =~ s/.*:([^:]+)$/fetch_databases_$1/;
  return $self->$ref($subject);
}

=head1 INTERNAL METHODS
=head2 store_DataReleaseInfo
  Description: Implementation of store for Bio::EnsEMBL::MetaData::DataReleaseInfo 
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub store_DataReleaseInfo {
  my ( $self, $data_release_database ) = @_;
  if ( !defined $data_release_database->dbID() ) {
    my ($dbID) = @{
      $self->dbc()->sql_helper()->execute_simple(
        -SQL => q/select data_release_database_id from data_release_database 
where dbname=? and data_release_id=?/,
        -PARAMS => [ $data_release_database->dbname(),
                     $data_release_database->subject()->dbID() ] ) };

    if ( defined $dbID ) {
      $data_release_database->dbID($dbID);
      $data_release_database->adaptor($self);
    }
    if ( defined $data_release_database->dbID() ) {
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

=head2 update_DataReleaseInfo
  Description: Implementation of update for Bio::EnsEMBL::MetaData::DataReleaseInfo
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stabl
=cut

sub update_DataReleaseInfo {
  my ( $self, $database ) = @_;
  if ( !defined $database->dbID() ) {
    croak "Cannot update an object that has not already been stored";
  }

  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
q/update data_release_database set data_release_id=?, type=?, division_id=?, dbname=? 
where data_release_database_id=?/,
    -PARAMS => [ $database->subject()->dbID(),
                 $database->type(),
                 $self->_get_division_id( $database->division() ),
                 $database->dbname() ] );
  return;
}

=head2 store_GenomeInfo
  Description: Implementation of store for Bio::EnsEMBL::MetaData::GenomeInfo
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub store_GenomeInfo {
  my ( $self, $genome_database ) = @_;
  if ( !defined $genome_database->dbID() ) {
    my ($dbID) = @{
      $self->dbc()->sql_helper()->execute_simple(
        -SQL => q/select genome_database_id from genome_database 
where dbname=? and genome_id=?/,
        -PARAMS =>
          [ $genome_database->dbname(), $genome_database->subject()->dbID() ] )
    };

    if ( defined $dbID ) {
      $genome_database->dbID($dbID);
      $genome_database->adaptor($self);
    }
    if ( defined $genome_database->dbID() ) {
      $self->update($genome_database);
    }
    else {
      $self->dbc()->sql_helper()->execute_update(
        -SQL => q/insert into genome_database(genome_id,type,species_id,dbname) 
values (?,?,?,?)/,
        -PARAMS => [ $genome_database->subject()->dbID(),
                     $genome_database->type(),
                     ( $genome_database->species_id() || 1 ),
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

=head2 update_GenomeInfo
  Description: Implementation of update for Bio::EnsEMBL::MetaData::GenomeInfo
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stabl
=cut

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
                 ( $database->species_id() || 1 ), $database->dbname() ] );
  return;
}

=head2 fetch_databases_DataReleaseInfo
  Description: Implementation of fetch_databases for Bio::EnsEMBL::MetaData::DataReleaseInfo
  Arg        : Bio::EnsEMBL::MetaData::DataReleaseInfo 
  Description: Find the databases associated with the supplied object
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::DatabaseInfo 
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

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

=head2 fetch_databases_GenomeInfo
  Description: Implementation of fetch_databases for Bio::EnsEMBL::MetaData::GenomeInfo
  Arg        : Bio::EnsEMBL::MetaData::GenomeInfo
  Arg        : String - Optional division
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::DatabaseInfo 
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_databases_GenomeInfo {

  my ( $self, $genome ) = @_;
  my $sql =
    q/select genome_database_id, dbname, type, species_id from genome_database 
where genome_id=?/;
  my $params    = [ $genome->dbID() ];
  my $databases = [];

  $self->dbc()->sql_helper()->execute_no_return(
    -SQL      => $sql,
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      push @{$databases},
        Bio::EnsEMBL::MetaData::DatabaseInfo->new( -SUBJECT    => $genome,
                                                   -DBID       => $row[0],
                                                   -DBNAME     => $row[1],
                                                   -TYPE       => $row[2],
                                                   -SPECIES_ID => $row[3] );
      return;
    },
    -PARAMS => $params );

  return $databases;
} ## end sub fetch_databases_GenomeInfo

1;
