
=head1 LICENSE

Copyright [1999-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::DBSQL::GenomeComparaInfoAdaptor

=head1 SYNOPSIS

# metadata_db is an instance of MetaDataDBAdaptor
my $adaptor = $metadata_db->get_GenomeComparaInfoAdaptor();
my @comparas = $adaptor->fetch_all_by_method('PROTEIN_TREES');
for my $genome (@{@comparas[0]->genomes()}) {
  print $genome->name()."\n";
}

=head1 DESCRIPTION

Adaptor for storing and retrieving GenomeComparaInfo objects from MySQL genome_info database

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::GenomeComparaInfo
Bio::EnsEMBL::MetaData::GenomeInfo

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBSQL::GenomeComparaInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw( throw );
use List::MoreUtils qw(natatime);
use Scalar::Util 'refaddr';

=head2 set_release
  Arg	     : Ensembl release number
  Description: Set release to use when querying 
  Returntype : None
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub set_ensembl_release {
  my ( $self, $release ) = @_;
  my $release_info =
    $self->db()->get_DataReleaseInfoAdaptor()
    ->fetch_by_ensembl_release($release);
  if ( !defined $release_info ) {
    throw "Could not find Ensembl release $release";
  }
  else {
    $self->data_release($release_info);
  }
  return;
}

=head2 set_ensembl_genomes_release
  Arg	     : Ensembl Genomes release number
  Description: Set release to use when querying 
  Returntype : None
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub set_ensembl_genomes_release {
  my ( $self, $release ) = @_;
  my $release_info;
  if ( !defined $release ) {
    $release_info =
      $self->db()->get_DataReleaseInfoAdaptor()
      ->fetch_current_ensembl_genomes_release($release);
  }
  else {
    $release_info =
      $self->db()->get_DataReleaseInfoAdaptor()
      ->fetch_by_ensembl_genomes_release($release);
  }
  if ( !defined $release_info ) {
    throw "Could not find Ensembl Genomes release $release";
  }
  else {
    $self->data_release($release_info);
  }
  return;
}

=head2 data_release
  Arg	     : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Description: Default release to use when querying 
  Returntype : None
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub data_release {
  my ( $self, $release ) = @_;
  if ( defined $release ) {
    if ( !defined $self->{data_release} ||
         refaddr($release) != refaddr( $self->{data_release} ) )
    {
      $self->{data_release} = $release;
      $self->db()->get_GenomeInfoAdaptor()->data_release($release);
    }
  }
  if ( !defined $self->{data_release} ) {
    # default to current Ensembl release
    $self->{data_release} =
      $self->db()->get_DataReleaseInfoAdaptor()
      ->fetch_current_ensembl_release();
    if ( defined $self->{data_release} ) {
      $self->db()->get_GenomeInfoAdaptor()
        ->data_release( $self->{data_release} );
    }
  }
  if ( defined $self->{data_release} && !defined $self->{data_release}->dbID() )
  {
    $self->db()->get_DataReleaseInfoAdaptor()->store( $self->{data_release} );
  }
  return $self->{data_release};
} ## end sub data_release

=head2 fetch_databases 
  Arg        : (optional) release
  Description: Fetch all compara-associated databases for the specified release
  Returntype : Arrayref of strings
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_databases {
  my ( $self, $release ) = @_;
  if ( !defined $release ) {
    $release = $self->data_release();
  }
  return $self->dbc()->sql_helper()->execute_simple(
    -SQL => q/select distinct c.dbname from compara_analysis c
      where data_release_id=?/,
    -PARAMS => [ $self->data_release()->dbID() ] );
}

=head2 fetch_databases 
  Arg        : division
  Arg        : (optional) release
  Description: Fetch all compara-associated databases for the specified release
  Returntype : Arrayref of strings
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_division_databases {
  my ( $self, $division, $release ) = @_;
  if ( !defined $release ) {
    $release = $self->data_release();
  }
  return $self->dbc()->sql_helper()->execute_simple(
    -SQL => qw/select distinct c.dbname from compara_analysis c
      join division d using (division_id)
      where data_release_id=? and (d.name=? OR d.short_name=?)/,
    -PARAMS => [ $self->data_release()->dbID(), $division, $division ] );
}

sub fetch_all_by_division {
  my ( $self, $division ) = @_;
  return $self->_fetch_generic_with_args( { division => $division } );
}

=head2 fetch_all_by_method
  Arg	     : Method of compara analyses to retrieve
  Description: Fetch compara specified compara analysis
  Returntype : array ref of  Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_method {
  my ( $self, $method ) = @_;
  return $self->_fetch_generic_with_args( { method => $method } );
}

=head2 fetch_by_dbname_method_set
  Arg	     : DBName of compara analyses to retrieve
  Arg	     : Method of compara analyses to retrieve
  Arg	     : Set of compara analyses to retrieve
  Description: Fetch specified compara analysis
  Returntype : Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_dbname_method_set {
  my ( $self, $dbname, $method, $set_name ) = @_;
  return
    _first_element(
               $self->_fetch_generic_with_args(
                 { dbname => $dbname, method => $method, set_name => $set_name }
               ) );
}

=head1 METHODS
=cut

=head2 update
  Arg	     : Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Description: Updates the supplied object and all associated  genomes
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub update {
  my ( $self, $compara ) = @_;
  if ( !defined $compara->dbID() ) {
    croak "Cannot update compara object with no dbID";
  }
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/update compara_analysis 
	  set method=?,division_id=?,set_name=?,dbname=?, data_release_id=?
	  where compara_analysis_id=?/,
    -PARAMS => [ $compara->method(),
                 $self->_get_division_id( $compara->division() ),
                 $compara->set_name(),
                 $compara->dbname(),
                 $self->data_release()->dbID(),
                 $compara->dbID() ] );
  $self->_store_compara_genomes($compara);
  $self->_store_cached_obj($compara);
  return;
}

=head2 store
  Arg	     : Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Description: Stores the supplied object and all associated  genomes (if not already stored)
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub store {
  my ( $self, $compara ) = @_;
  # check if it already exists
  if ( !defined $compara->dbID() ) {
    # find out if compara exists first
    my ($dbID) =
      @{
      $self->dbc()->sql_helper()->execute_simple(
        -SQL =>
q/select compara_analysis_id from compara_analysis where division_id=? and method=? and set_name=? and dbname=?/,
        -PARAMS => [ $self->_get_division_id( $compara->division() ),
                     $compara->method(), $compara->set_name(),
                     $compara->dbname() ] ) };
    if ( defined $dbID ) {
      $compara->dbID($dbID);
      $compara->adaptor($self);
    }
  }
  if ( defined $compara->dbID() ) {
    return $self->update($compara);
  }
  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
q/insert into compara_analysis(method,division_id,set_name,dbname,data_release_id)
		values(?,?,?,?,?)/,
    -PARAMS => [ $compara->method(),
                 $self->_get_division_id( $compara->division() ),
                 $compara->set_name(),
                 $compara->dbname(),
                 $self->data_release()->dbID() ],
    -CALLBACK => sub {
      my ( $sth, $dbh, $rv ) = @_;
      $compara->dbID( $dbh->{mysql_insertid} );
    } );
  $self->_store_compara_genomes($compara);
  $self->_store_cached_obj($compara);
  return;
} ## end sub store

sub _store_compara_genomes {
  my ( $self, $compara ) = @_;
  $self->dbc()->sql_helper()->execute_update(
     -SQL => q/delete from genome_compara_analysis where compara_analysis_id=?/,
     -PARAMS => [ $compara->dbID() ] );
  if ( defined $compara->genomes() ) {
    for my $genome ( @{ $compara->genomes() } ) {
      if ( !defined $genome->dbID() ) {
        $self->get_GenomeInfoAdaptor()->store($genome);
      }
      $self->dbc()->sql_helper()->execute_update(
        -SQL =>
          q/insert into genome_compara_analysis(genome_id,compara_analysis_id)
		values(?,?)/,
        -PARAMS => [ $genome->dbID(), $compara->dbID() ] );
    }
  }
  return;
}

=head2 _fetch_children
    Arg	     : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Fetch all children of specified genome info object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_children {
  my ( $self, $compara ) = @_;
  $self->_fetch_compara_genomes($compara);
  return;
}

sub _fetch_compara_genomes {
  my ( $self, $compara ) = @_;
# add genomes on one by one (don't nest the fetch here as could run of connections)
  if ( !defined $compara->{genomes} ) {
    my $genomes = [];
    for my $genome_id (
      @{$self->dbc()->sql_helper()->execute_simple(
          -SQL =>
q/select distinct(genome_id) from genome_compara_analysis where compara_analysis_id=?/,
          -PARAMS => [ $compara->dbID() ] );
      } )
    {
      push @$genomes, $self->db()->get_GenomeInfoAdaptor()->fetch_by_dbID($genome_id);
    }
    $compara->genomes($genomes);
  }
  return;
}

my $base_compara_fetch_sql =
q/select compara_analysis_id as dbID, method,division.name as division,set_name,dbname,data_release_id from compara_analysis join division using (division_id)/;

sub _get_base_sql {
  return $base_compara_fetch_sql;
}

sub _get_id_field {
  return 'compara_analysis_id';
}

sub _get_obj_class {
  return 'Bio::EnsEMBL::MetaData::GenomeComparaInfo';
}

# override to add release clause
sub _args_to_sql {
  my ( $self, $sql_in, $args ) = @_;
  if ( !defined $args->{ _get_id_field() } ) {
    # if we're not searching by dbID, add release as a clause
    if ( defined $self->data_release()->dbID() ) {
      $args->{data_release_id} = $self->data_release()->dbID();
    }
  }
  return $self->SUPER::_args_to_sql( $sql_in, $args );
}

1;
