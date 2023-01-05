
=head1 LICENSE

Copyright [1999-2023] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor

=head1 SYNOPSIS

# metadata_db is an instance of MetaDataDBAdaptor
my $adaptor = $metadata_db->get_DataReleaseInfoAdaptor();
# find the latest e! release
my $release = $adaptor->fetch_current_ensembl_release();
# find associated databases
$adaptor->fetch_databases($release);

=head1 DESCRIPTION

Adaptor for storing and retrieving DataRelease objects from MySQL genome_info database

=head1 AUTHOR

Dan Staines

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::DataReleaseInfo
Bio::EnsEMBL::MetaData::DatabaseInfo
Bio::EnsEMBL::MetaData::GenomeInfo

=cut

package Bio::EnsEMBL::MetaData::DBSQL::DataReleaseInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::MetaData::DataReleaseInfo;

=head1 METHODS
=head2 store
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Description: Store the supplied object
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub store {
  my ( $self, $data_release ) = @_;
  $self->dbc()->sql_helper()->transaction(
    -CALLBACK => sub {
      if ( !defined $data_release->dbID() ) {
        # find out if organism exists first
        my $dbID;
        if ( defined $data_release->ensembl_genomes_version() ) {
          ($dbID) =
            @{
            $self->dbc()->sql_helper()->execute_simple(
              -SQL =>
    "select data_release_id from data_release where ensembl_version=? and ensembl_genomes_version=?",
              -PARAMS => [ $data_release->ensembl_version(),
                          $data_release->ensembl_genomes_version() ] ) };
        }
        else {
          ($dbID) =
            @{
            $self->dbc()->sql_helper()->execute_simple(
              -SQL =>
    "select data_release_id from data_release where ensembl_version=? and ensembl_genomes_version is null",
              -PARAMS => [ $data_release->ensembl_version() ] ) };
        }

        if ( defined $dbID ) {
          $data_release->dbID($dbID);
          $data_release->adaptor($self);
        }
      } ## end if ( !defined $data_release...)
      if ( defined $data_release->dbID() ) {
        $self->update($data_release);
      }
      else {
        #Remove current release before the add the new release
        if ($data_release->is_current()){
          my $current_release;
          if ( defined $data_release->ensembl_genomes_version() ) {
            $current_release = $self->fetch_current_ensembl_genomes_release();
          }
          else {
            $current_release = $self->fetch_current_ensembl_release();
          }
          if (defined $current_release){
            $self->db()->get_DatabaseInfoAdaptor()->clear_current_release($current_release);
          }
        }
        $self->dbc()->sql_helper()->execute_update(
          -SQL =>
    q/insert into data_release(ensembl_version,ensembl_genomes_version,release_date,is_current) values (?,?,?,?)/,
          -PARAMS => [ $data_release->ensembl_version(),
                      $data_release->ensembl_genomes_version(),
                      $data_release->release_date(),
                      $data_release->is_current() ],
          -CALLBACK => sub {
            my ( $sth, $dbh, $rv ) = @_;
            $data_release->dbID( $dbh->{mysql_insertid} );
          } );
        $data_release->adaptor($self);
        $self->_store_databases($data_release);
        $self->_store_cached_obj($data_release);
      }
      return 1;
  });
  return;
} ## end sub store
=head2 update
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Description: Update the supplied object (must be previously stored)
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub update {
  my ( $self, $data_release ) = @_;
  $self->dbc()->sql_helper()->transaction(
    -CALLBACK => sub {
      if ( !defined $data_release->dbID() ) {
        croak "Cannot update an object that has not already been stored";
      }
      #Remove current release before the add the new release
      if ($data_release->is_current()){
        my $current_release;
        if ( defined $data_release->ensembl_genomes_version() ) {
          $current_release = $self->fetch_current_ensembl_genomes_release();
        }
        else {
          $current_release = $self->fetch_current_ensembl_release();
        }
        $self->db()->get_DatabaseInfoAdaptor()->clear_current_release($current_release);
      }
      $self->dbc()->sql_helper()->execute_update(
        -SQL =>
    q/update data_release set ensembl_version=?, ensembl_genomes_version=?, release_date=?, is_current=? where data_release_id=?/,
        -PARAMS => [ $data_release->ensembl_version(),
                    $data_release->ensembl_genomes_version(),
                    $data_release->release_date(),
                    $data_release->is_current(),
                    $data_release->dbID() ] );

      $self->_store_databases($data_release);
      return 1;
  });
  return;
}

=head2 fetch_by_ensembl_release
  Arg        : String - Ensembl Release
  Description: Retrieve details for the specified Ensembl release
  Returntype : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub fetch_by_ensembl_release {
  my ( $self, $release ) = @_;
  my $ens_release = $self->_first_element(
             $self->_fetch_generic(
               _get_base_sql() .
                 ' where ensembl_version=? and ensembl_genomes_version is null',
               [$release] ) );
  if (!defined $ens_release){
    $ens_release = $self->_first_element(
             $self->_fetch_generic(
               _get_base_sql() .
                 ' where ensembl_version=? order by ensembl_genomes_version desc',
               [$release] ) );
  }
  return $ens_release;
}
=head2 fetch_by_ensembl_genomes_release
  Arg        : String - Ensembl Genomes Release
  Description: Retrieve details for the specified Ensembl Genomes release
  Returntype : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub fetch_by_ensembl_genomes_release {
  my ( $self, $release ) = @_;
  return
    $self->_first_element(
                         $self->_fetch_generic(
                           _get_base_sql() . ' where ensembl_genomes_version=?',
                           [$release] ) );
}
=head2 fetch_current_ensembl_release
  Description: Retrieve details for the current Ensembl release
  Returntype : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub fetch_current_ensembl_release {
  my ($self) = @_;
    my $ens_release = $self->_first_element(
             $self->_fetch_generic(
               _get_base_sql() .
                 ' where ensembl_genomes_version is null and is_current=1' ) );
  if (!defined $ens_release){
    $ens_release = $self->_first_element(
             $self->_fetch_generic(
               _get_base_sql() .
                 ' where is_current=1' ) );
  }
  return $ens_release;
}
=head2 fetch_current_ensembl_genomes_release
  Description: Retrieve details for the current Ensembl Genomes release
  Returntype : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub fetch_current_ensembl_genomes_release {
  my ($self) = @_;
  return
    $self->_first_element(
    $self->_fetch_generic(
      _get_base_sql() .
' where ensembl_genomes_version is not null and is_current=1 order by release_date desc limit 1'
    ) );
}
=head2 
  Arg        : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Arg        : String - (optional) division
  Description: Retrieve databases associated with the specified release
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::DatabaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub fetch_databases {
  my ( $self, $release, $division ) = @_;
  my $databases = $release->databases();
  if(defined $division) {
    $databases = [grep {$division eq $_->division()} @{$release->databases()}];
  }
  if ( defined $division ) {
    $databases = [ @$databases,
                   @{$self->db()->get_GenomeInfoAdaptor()
                       ->fetch_division_databases( $division, $release ) },
                   @{$self->db()->get_GenomeInfoAdaptor()
                       ->fetch_division_databases( $division, $release ) } ];
  }
  else {
    $databases = [ @$databases,
                   @{$self->db()->get_GenomeInfoAdaptor()
                       ->fetch_databases($release) },
                   @{$self->db()->get_GenomeInfoAdaptor()
                       ->fetch_databases($release) } ];
  }
  return $databases;
} ## end sub fetch_databases

=head1 INTERNAL METHODS
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
  $self->_fetch_databases($md);
  return;
}

=head2 _fetch_databases
  Arg	     : Bio::EnsEMBL::MetaData::DataReleaseInfo 
  Description: Add databases to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_databases {
  my ( $self, $release ) = @_;
  croak
"Cannot fetch databases for a DataReleaseInfo object that has not been stored"
    if !defined $release->dbID();
  my $databases =
    $self->db()->get_DatabaseInfoAdaptor()
    ->fetch_databases($release);
  $release->databases($databases);
  return;
}

=head2 _store_databases
  Arg	     : Bio::EnsEMBL::MetaData::DataReleaseInfo 
  Description: Store databases from supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_databases {
  my ( $self, $release ) = @_;
  $self->db()->get_DatabaseInfoAdaptor()->clear_release_databases($release);
  for my $database ( @{ $release->databases() } ) {
    print "Storing database ".$database->dbname()."\n";
        $self->db()->get_DatabaseInfoAdaptor()->store($database);
  }
  return;
}
# internal implementation
my $base_data_release_fetch_sql =
q/select data_release_id as dbID, ensembl_version, ensembl_genomes_version, release_date from data_release/;

sub _get_base_sql {
  return $base_data_release_fetch_sql;
}

sub _get_id_field {
  return 'data_release_id';
}

sub _get_obj_class {
  return 'Bio::EnsEMBL::MetaData::DataReleaseInfo';
}

1;
