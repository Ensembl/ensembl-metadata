
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

Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor

=head1 SYNOPSIS

# metadata_db is an instance of MetaDataDBAdaptor
my $adaptor = $metadata_db->get_GenomeInfoAdaptor();
my $md = $gdba->fetch_by_name("homo_sapiens");

=head1 DESCRIPTION

Adaptor for storing and retrieving GenomeInfo objects from MySQL ensembl_metadata database

To start working with an adaptor:

# getting an adaptor
## adaptor for latest public Ensembl release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_ensembl_adaptor();
## adaptor for specified public Ensembl release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_ensembl_adaptor(83);
## adaptor for latest public EG release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_ensembl_genomes_adaptor();
## adaptor for specified public EG release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_ensembl_genome_adaptor(30);
## manually specify a given database
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->new(-USER=>'anonymous',
-PORT=>4157,
-HOST=>'mysql-eg-publicsql.ebi.ac.uk',
-DBNAME=>'ensembl_metadata');

To find genomes, use the fetch methods. These will work with the release set on the adaptor
which is the latest Ensembl release by default.

# find a genome by name
my $genome = $gdba->fetch_by_name('homo_sapiens');

# find and iterate over all genomes
for my $genome (@{$gdba->fetch_all()}) {
	print $genome->name()."\n";
}

# find and iterate over all genomes with variation
for my $genome (@{$gdba->fetch_all_with_variation()}) {
	print $genome->name()."\n";
}

# to change the release
$gdba->set_ensembl_release(82);
$gdba->set_ensembl_genomes_release(82);

my $genome = $gdba->fetch_by_name('arabidopsis_thaliana');

# find and iterate over all genomes from plants
for my $genome (@{$gdba->fetch_all_by_division('EnsemblPlants')}) {
	print $genome->name()."\n";
}

# find all comparas for the division of interest
my $comparas = $gdba->fetch_all_compara_by_division('EnsemblPlants');

# find the peptide compara
my ($compara) = grep {$_->is_peptide_compara()} @$comparas;
print $compara->division()." ".$compara->method()."(".$compara->dbname().")\n";

# print out all the genomes in this compara
for my $genome (@{$compara->genomes()}) {
	print $genome->name()."\n";
}

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::GenomeInfo
Bio::EnsEMBL::MetaData::GenomeComparaInfo
Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
Bio::EnsEMBL::MetaData::GenomeOrganismInfo

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::MetaData::GenomeInfo;
use Data::Dumper;
use Scalar::Util qw(looks_like_number refaddr);
use Bio::EnsEMBL::Utils::PublicMySQLServer qw/e_args eg_args/;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;

=head1 METHODS

=head2 build_ensembl_adaptor
  Arg	     : (optional) Ensembl release number - default is latest
  Description: Build an adaptor for the public Ensembl metadata database
  Returntype : Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub build_ensembl_adaptor {
  my ( $self, $release ) = @_;
  my $args = e_args();
  $args->{-DBNAME} = 'ensembl_metadata';
  my $adaptor =
    Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->new(
        Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(%$args) );
  if ( defined $release ) {
    $adaptor->set_ensembl_release($release);
  }
  return $adaptor;
}

=head2 build_ensembl_genomes_adaptor
  Arg	     : (optional) EG release number  - default is latest
  Description: Build an adaptor for the public Ensembl Genomes metadata database
  Returntype : Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub build_ensembl_genomes_adaptor {
  my ( $self, $release ) = @_;
  my $args = eg_args();
  $args->{-DBNAME} = 'ensembl_metadata';
  my $adaptor =
    Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->new(
        Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(%$args) );
  $adaptor->set_ensembl_genomes_release($release);
  return $adaptor;
}

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
    # replace release if we've been given something different
    if ( !defined $self->{data_release} ||
         refaddr($release) != refaddr( $self->{data_release} ) )
    {
      $self->{data_release} = $release;
      $self->db()->get_GenomeComparaInfoAdaptor()
        ->data_release($release);
    }
  }
  if ( !defined $self->{data_release} ) {
    # default to current Ensembl release
    $self->{data_release} =
      $self->db()->get_DataReleaseInfoAdaptor()
      ->fetch_current_ensembl_release();
    if ( defined $self->{data_release} ) {
      $self->db()->get_GenomeComparaInfoAdaptor()
        ->data_release( $self->{data_release} );
    }
  }
  if ( !defined $self->{data_release}->dbID() ) {
    $self->db()->get_DataReleaseInfoAdaptor()
      ->store( $self->{data_release} );
  }
  return $self->{data_release};
} ## end sub data_release

=head2 store
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Stores the supplied object and all associated child objects (includes other genomes attached by compara if not already stored)
  Returntype : None
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub store {
  my ( $self, $genome ) = @_;
    $DB::single = 1;
  if ( !defined $genome->data_release() ) {
    $genome->data_release( $self->data_release() );
  }
  if ( !defined $genome->data_release()->dbID() ) {
    $self->db()->get_DataReleaseInfoAdaptor()
      ->store( $genome->data_release() );
  }
  if ( !defined $genome->organism() ) {
    throw("Genome must be associated with an organism");
  }
  if ( !defined $genome->assembly() ) {
    throw("Genome must be associated with an assembly");
  }
  if ( !defined $genome->assembly()->dbID() ) {
    $self->db()->get_GenomeAssemblyInfoAdaptor()
      ->store( $genome->assembly() );
  }
  if ( !defined $genome->dbID() ) {
    # find out if genome exists first
    my ($dbID) =
      @{
      $self->dbc()->sql_helper()->execute_simple(
        -SQL =>
"select genome_id from genome where data_release_id=? and assembly_id=?",
        -PARAMS => [ $genome->data_release()->dbID(),
                     $genome->assembly()->dbID() ] ) };

    if ( defined $dbID ) {
      $genome->dbID($dbID);
      $genome->adaptor($self);
    }
  }

  if ( defined $genome->dbID() ) {
    return $self->update($genome);
  }
  else {
    # Check if we already have this genome for this given release
    # This will usually happen when the assembly change.
    # Remove this genome from database to avoid duplication
    my $release_genome = $self->fetch_by_name($genome->{organism}->{name});
    if (defined $release_genome){
      $self->clear_genome($release_genome);
    }
  }
  $self->db()->get_GenomeOrganismInfoAdaptor()
    ->store( $genome->organism() );
  $self->db()->get_GenomeAssemblyInfoAdaptor()
    ->store( $genome->assembly() );
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/insert into genome(division_id,
genebuild,has_pan_compara,has_variations,has_peptide_compara,
has_genome_alignments,has_synteny,has_other_alignments,assembly_id,organism_id,data_release_id)
		values(?,?,?,?,?,?,?,?,?,?,?)/,
    -PARAMS => [ $self->_get_division_id( $genome->division() ),
                 $genome->genebuild(),
                 $genome->has_pan_compara(),
                 $genome->has_variations(),
                 $genome->has_peptide_compara(),
                 $genome->has_genome_alignments(),
                 $genome->has_synteny(),
                 $genome->has_other_alignments(),
                 $genome->assembly()->dbID(),
                 $genome->organism()->dbID(),
                 $genome->data_release()->dbID() ],
    -CALLBACK => sub {
      my ( $sth, $dbh, $rv ) = @_;
      $genome->dbID( $dbh->{mysql_insertid} );
    } );
  $genome->adaptor($self);
  $self->_store_databases($genome);
  $self->_store_annotations($genome);
  $self->_store_features($genome);
  $self->_store_variations($genome);
  $self->_store_alignments($genome);
  #$self->_store_compara($genome);
  $self->_store_cached_obj($genome);
  return;
} ## end sub store

=head2 update
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Updates the supplied object and all associated child objects (includes other genomes attached by compara if not already stored)
  Returntype : None
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub update {
  my ( $self, $genome ) = @_;
  $DB::single = 1;
  if ( !defined $genome->dbID() ) {
    croak "Cannot update an object that has not already been stored";
  }
  if ($genome->{databases}->[0]->type() eq 'core'){
    $self->db()->get_GenomeOrganismInfoAdaptor()
      ->store( $genome->organism() );
    $self->db()->get_GenomeAssemblyInfoAdaptor()
      ->store( $genome->assembly() );
    $self->dbc()->sql_helper()->execute_update(
      -SQL => q/update genome set division_id=?,
genebuild=?,has_pan_compara=?,has_variations=?,has_peptide_compara=?,
has_genome_alignments=?,has_synteny=?,has_other_alignments=?,assembly_id=?,organism_id=?,data_release_id=? where genome_id=?/
    ,
      -PARAMS => [ $self->_get_division_id( $genome->division() ),
                 $genome->genebuild(),
                 $genome->has_pan_compara(),
                 $genome->has_variations(),
                 $genome->has_peptide_compara(),
                 $genome->has_genome_alignments(),
                 $genome->has_synteny(),
                 $genome->has_other_alignments(),
                 $genome->assembly()->dbID(),
                 $genome->organism()->dbID(),
                 $genome->data_release()->dbID(),
                 $genome->dbID() ] );
  }
  $genome->adaptor($self);
  $self->_store_databases($genome);
  if ($genome->{databases}->[0]->type() eq 'core'){
    $self->_store_annotations($genome);
    $self->_store_features($genome);
  }
  if ($genome->{databases}->[0]->type() eq 'variation') {
    $self->_store_variations($genome);
  }
  if ($genome->{databases}->[0]->type() eq 'core' or $genome->{databases}->[0]->type() eq 'otherfeatures' or $genome->{databases}->[0]->type() eq 'rnaseq'){
    $self->_store_alignments($genome);
  }
  #$self->_store_compara($genome);
  return;
} ## end sub update

=head2 update_booleans
  Description: Updates boolean genome attributes for all genomes
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub update_booleans {
  my ($self) = @_;

  #has_peptide_compara
  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
q/update genome g join genome_compara_analysis gc using (genome_id) 
	  join compara_analysis c using (compara_analysis_id) 
          join division d on (c.division_id=d.division_id)
	  set g.has_peptide_compara=1 where d.name<>'EnsemblPan' and
	  c.method='PROTEIN_TREES'/
  );

  #has_pan_compara
  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
q/update genome g join genome_compara_analysis gc using (genome_id) 
	  join compara_analysis c using (compara_analysis_id) 
          join division d on (c.division_id=d.division_id)
	  set g.has_pan_compara=1 where d.name='EnsemblPan' and
	  c.method='PROTEIN_TREES'/
  );

  #has_genome_alignments
  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
q/update genome g join genome_compara_analysis gc using (genome_id) 
	  join compara_analysis c using (compara_analysis_id) 
	  set g.has_genome_alignments=1 where c.method in 
	  ('TRANSLATED_BLAT_NET','LASTZ_NET','TBLAT','ATAC','BLASTZ_NET')/
  );

  #has_synteny
  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
q/update genome g join genome_compara_analysis gc using (genome_id) 
	  join compara_analysis c using (compara_analysis_id) 
	  set g.has_synteny=1 where c.method='SYNTENY'/
  );

  #has_other_alignments
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/update genome g join genome_alignment a using (genome_id) 
	  set g.has_other_alignments=1/
  );

  #has_variations
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/update genome g join genome_variation a using (genome_id)
	  set g.has_variations=1/
  );

  return;
} ## end sub update_booleans

=head2 fetch_databases 
  Arg        : release (optional)
  Description: Fetch all genome-associated databases for the specified release
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
    -SQL => q/select distinct dbname from genome_database
      join genome using (genome_id) where data_release_id=?/,
    -PARAMS => [ $release->dbID() ] );
}

=head2 fetch_division_databases 
  Arg        : division
  Arg        : release (optional)
  Description: Fetch all genome-associated databases for the specified release
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
    -SQL => q/select distinct gd.dbname from genome_database gd
      join genome g using (genome_id)
      join division d using (division_id)
      where data_release_id=? and (d.name=? OR d.short_name=?)/,
    -PARAMS => [ $release->dbID(), $division, $division ] );
}

=head2 fetch_by_organism 
  Arg	     : Bio::EnsEMBL::MetaData::GenomeOrganismInfo
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified organism
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_organism {
  my ( $self, $organism, $keen ) = @_;
  if ( ref($organism) eq 'Bio::EnsEMBL::MetaData::GenomeOrganismInfo' )
  {
    $organism = $organism->dbID();
  }
  return
    $self->_first_element( $self->_fetch_generic_with_args(
                                     { 'organism_id', $organism }, $keen
                           ) );
}

=head2 fetch_all_by_organisms
  Arg	     : Array ref of Bio::EnsEMBL::MetaData::GenomeOrganismInfo
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified organisms
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_organisms {
  my ( $self, $organisms, $keen ) = @_;
  if ( !defined $organisms || scalar($organisms) == 0 ) {
    return [];
  }
  return
    $self->_fetch_generic_with_args(
    { 'organism_id', [ map { $_->dbID() } @$organisms ] },
    $keen );
}

=head2 fetch_by_taxonomy_id
  Arg	     : Taxonomy ID
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified taxonomy node
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeOrganismInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_taxonomy_id {
  my ( $self, $id, $keen ) = @_;
  return $self->fetch_all_by_organisms(
            $self->_organism_adaptor()->fetch_all_by_taxonomy_id($id) );
}

=head2 fetch_by_taxonomy_ids
  Arg	     : Arrayref of Taxonomy ID
  Description: Fetch genome info for specified taxonomy nodes (batch)
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeOrganismInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_taxonomy_ids {
  my ( $self, $ids ) = @_;
  return $self->fetch_all_by_organisms(
          $self->_organism_adaptor()->fetch_all_by_taxonomy_ids($ids) );
}

=head2 fetch_all_by_taxonomy_branch
  Arg	     : Bio::EnsEMBL::TaxonomyNode
  Description: Fetch organism info for specified taxonomy node and its children
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeOrganismInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_taxonomy_branch {
  my ( $self, $root, $keen ) = @_;
  return $self->fetch_all_by_organisms( $self->_organism_adaptor()
                       ->fetch_all_by_taxonomy_branch( $root, $keen ) );
}

=head2 fetch_by_assembly 
  Arg	     : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_assembly {
  my ( $self, $assembly, $keen ) = @_;
  if ( ref($assembly) eq 'Bio::EnsEMBL::MetaData::GenomeAssemblyInfo' )
  {
    $assembly = $assembly->dbID();
  }
  return
    $self->_first_element( $self->_fetch_generic_with_args(
                                     { 'assembly_id', $assembly }, $keen
                           ) );
}

=head2 fetch_all_by_assemblies 
  Arg	     : array of Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_assemblies {
  my ( $self, $assemblies, $keen ) = @_;
  if ( !defined $assemblies || scalar(@$assemblies) == 0 ) {
    return [];
  }
  return
    $self->_fetch_generic_with_args(
    { 'assembly_id', [ map { $_->dbID() } @$assemblies ] },
    $keen );
}

=head2 fetch_all_by_sequence_accession
  Arg	     : INSDC sequence accession e.g. U00096.1 or U00096
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified sequence accession
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_sequence_accession {
  my ( $self, $id, $keen ) = @_;
  my $ass =
    $self->_assembly_adaptor()
    ->fetch_all_by_sequence_accession_versioned($id);
  my $infos = $self->fetch_all_by_assemblies( $ass, $keen );
  if ( !defined $infos || scalar(@$infos) == 0 ) {
    $ass =
      $self->_assembly_adaptor()
      ->fetch_all_by_sequence_accession_unversioned($id);
    $infos = $self->fetch_all_by_assemblies( $ass, $keen );
  }
  return $infos;
}

=head2 fetch_all_by_sequence_accession_unversioned
  Arg	     : INSDC sequence accession e.g. U00096
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified sequence accession
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_sequence_accession_unversioned {
  my ( $self, $id, $keen ) = @_;
  my $ass =
    $self->_assembly_adaptor()
    ->fetch_all_sequence_accession_unversioned($id);
  return $self->fetch_all_by_assemblies( $ass, $keen );
}

=head2 fetch_all_by_sequence_accession_versioned
  Arg	     : INSDC sequence accession e.g. U00096.1
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified sequence accession
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_sequence_accession_versioned {
  my ( $self, $id, $keen ) = @_;
  my $ass =
    $self->_assembly_adaptor()
    ->fetch_all_sequence_accession_versioned($id);
  return $self->fetch_all_by_assemblies( $ass, $keen );
}

=head2 fetch_by_assembly_accession
  Arg	     : INSDC assembly accession
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly ID (versioned or unversioned)
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_assembly_accession {
  my ( $self, $id, $keen ) = @_;
  my $ass =
    $self->_assembly_adaptor()->fetch_by_assembly_accession($id);
  return $self->fetch_by_assembly( $ass, $keen );
}

=head2 fetch_all_by_assembly_set_chain
  Arg	     : INSDC assembly set chain (unversioned accession)
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly set chain
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_assembly_set_chain {
  my ( $self, $id, $keen ) = @_;
  my $ass =
    $self->_assembly_adaptor()->fetch_all_by_assembly_set_chain($id);
  return $self->fetch_all_by_assemblies( $ass, $keen );
}

=head2 fetch_all_by_division
  Arg	     : Name of division
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome infos for specified division
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_division {
  my ( $self, $division, $keen ) = @_;
  my ($sql, $params) =
    $self->_args_to_sql($self->_get_base_sql(),{});
  if($sql !~ m/where/) {
    $sql .=
      ' where division.name=? or division.short_name=?';
  } else {
    $sql .=
      ' and (division.name=? or division.short_name=?)';
  }
 return
   $self->_fetch_generic( $sql, [@{$params}, $division, $division ],
                          $self->_get_obj_class(), $keen );
}

=head2 fetch_by_display_name
  Arg	     : Production name of genome 
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_display_name {
  my ( $self, $name, $keen ) = @_;
  my $org = $self->_organism_adaptor()->fetch_by_display_name($name);
  return $self->fetch_by_organism( $org, $keen );
}

=head2 fetch_by_name
  Arg	     : Display name of genome 
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_name {
  my ( $self, $name, $keen ) = @_;
  my $org = $self->_organism_adaptor()->fetch_by_name($name);
  return $self->fetch_by_organism( $org, $keen );
}

=head2 fetch_by_any_name
  Arg	     : Name of genome (display, species, alias etc)
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_any_name {
  my ( $self, $name, $keen ) = @_;
  my $org = $self->_organism_adaptor()->fetch_by_name($name);
  if ( !defined $org ) {
    $org = $self->_organism_adaptor()->fetch_by_alias($name);
  }
  return $self->fetch_by_organism( $org, $keen );
}

=head2 fetch_all_by_dbname
  Arg	     : Name of database
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified database
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_dbname {
  my ( $self, $name, $keen ) = @_;
  return $self->_fetch_generic_with_args( { 'dbname', $name }, $keen );
}

=head2 fetch_all_by_name_pattern
  Arg	     : Regular expression matching of genome
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_name_pattern {
  my ( $self, $name, $keen ) = @_;
  my $orgs =
    $self->_organism_adaptor()->fetch_all_by_name_pattern($name);
  return $self->fetch_all_by_organisms( $orgs, $keen );
}

=head2 fetch_by_alias
  Arg	     : Alias of genome
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_alias {
  my ( $self, $name, $keen ) = @_;
  my $org =
    $self->_organism_adaptor()->fetch_all_by_name_pattern($name);
  return $self->fetch_by_organism( $org, $keen );
}

=head2 fetch_all_with_variation
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have variation data
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_variation {
  my ( $self, $keen ) = @_;
  return
    $self->_fetch_generic_with_args( { 'has_variations' => '1' },
                                     $keen );
}

=head2 fetch_all_with_peptide_compara
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have peptide compara data
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_peptide_compara {
  my ( $self, $keen ) = @_;
  return
    $self->_fetch_generic_with_args( { 'has_peptide_compara' => '1' },
                                     $keen );
}

=head2 fetch_all_with_pan_compara
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have pan comapra data
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_pan_compara {
  my ( $self, $keen ) = @_;
  return
    $self->_fetch_generic_with_args( { 'has_pan_compara' => '1' },
                                     $keen );
}

=head2 fetch_all_with_genome_alignments
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have whole genome alignment data
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_genome_alignments {
  my ( $self, $keen ) = @_;
  return
    $self->_fetch_generic_with_args( { 'has_genome_alignments' => '1' },
                                     $keen );
}

=head2 fetch_all_with_compara
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have any compara or whole genome alignment data
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_compara {
  my ( $self, $keen ) = @_;
  return $self->_fetch_generic( $self->_get_base_sql() .
q/ where has_genome_alignments=1 or has_pan_compara=1 or has_peptide_compara=1/
  );
}

=head2 fetch_with_other_alignments
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have other alignment data
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_other_alignments {
  my ( $self, $keen ) = @_;
  return
    $self->_fetch_generic_with_args( { 'has_other_alignments' => '1' },
                                     $keen );
}

=head2 list_divisions
  Description: Fetch all divisions for which we have genomes
  Returntype : arrayref of String
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub list_divisions {
  my ( $self, $keen ) = @_;
  return
    $self->{dbc}->sql_helper()->execute_simple(
    -SQL =>
q/select distinct(name) from division join genome using (division_id) where data_release_id=?/,
    -PARAMS => [ $self->data_release()->dbID() ] );
}

=head1 INTERNAL METHODS
=head2 _fetch_assembly
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add assembly to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_assembly {
  my ( $self, $genome ) = @_;
  if ( defined $genome->{assembly_id} ) {
    $genome->assembly( $self->db()->get_GenomeAssemblyInfoAdaptor()
                       ->fetch_by_dbID( $genome->{assembly_id} ) );
  }
  return;
}

=head2 _fetch_organism
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add organism to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_organism {
  my ( $self, $genome ) = @_;
  if ( defined $genome->{organism_id} ) {
    $genome->organism( $self->db()->get_GenomeOrganismInfoAdaptor()
                       ->fetch_by_dbID( $genome->{organism_id} ) );
  }
  return;
}

=head2 _fetch_data_release
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add data release to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_data_release {
  my ( $self, $genome ) = @_;
  if ( defined $genome->{data_release_id} ) {
    $genome->data_release( $self->db()->get_DataReleaseInfoAdaptor()
                        ->fetch_by_dbID( $genome->{data_release_id} ) );
  }
  return;
}

=head2 _fetch_variations
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add variations to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_variations {
  my ( $self, $genome ) = @_;
  croak " Cannot fetch variations
    for a GenomeInfo object that has not been stored "
    if !defined $genome->dbID();
  my $variations = {};
  $self->dbc()->sql_helper()->execute_no_return(
    -SQL =>
      'select type,name,count from genome_variation where genome_id=?',
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      $variations->{ $row[0] }->{ $row[1] } = $row[2];
      return;
    },
    -PARAMS => [ $genome->dbID() ] );
  $genome->variations($variations);
  $genome->has_variations();
  return;
}

=head2 _fetch_databases
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add databases to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_databases {
  my ( $self, $genome ) = @_;
  croak " Cannot fetch databases
    for a GenomeInfo object that has not been stored "
    if !defined $genome->dbID();
  $genome->{databases} =
    $self->db()->get_DatabaseInfoAdaptor()->fetch_databases($genome);
  return;
}

=head2 _fetch_other_alignments
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add other_alignments to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_other_alignments {
  my ( $self, $genome ) = @_;
  croak " Cannot fetch alignments
    for a GenomeInfo object that has not been stored "
    if !defined $genome->dbID();
  my $alignments = {};
  $self->dbc()->sql_helper()->execute_no_return(
    -SQL =>
      'select type,name,count from genome_alignment where genome_id=?',
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      $alignments->{ $row[0] }->{ $row[1] } = $row[2];
      return;
    },
    -PARAMS => [ $genome->dbID() ] );
  $genome->other_alignments($alignments);
  $genome->has_other_alignments();
  return;
}

=head2 _fetch_annotations
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add annotations to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_annotations {
  my ( $self, $genome ) = @_;
  croak " Cannot fetch annotations
    for a GenomeInfo object that has not been stored "
    if !defined $genome->dbID();
  my $annotations = {};
  $self->dbc()->sql_helper()->execute_no_return(
    -SQL =>
      'select type,value from genome_annotation where genome_id=?',
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      $annotations->{ $row[0] } = $row[1];
      return;
    },
    -PARAMS => [ $genome->dbID() ] );
  $genome->annotations($annotations);
  return;
}

=head2 _fetch_features
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add features to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_features {
  my ( $self, $genome ) = @_;
  croak " Cannot fetch features
    for a GenomeInfo object that has not been stored "
    if !defined $genome->dbID();
  my $features = {};
  $self->dbc()->sql_helper()->execute_no_return(
    -SQL =>
'select type,analysis,count from genome_feature where genome_id=?',
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      $features->{ $row[0] }->{ $row[1] } = $row[2];
      return;
    },
    -PARAMS => [ $genome->dbID() ] );
  $genome->features($features);
  return;
}

=head2 _fetch_comparas
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add compara info to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_comparas {
  my ( $self, $genome ) = @_;
  my $comparas = [];
  for my $id (
    @{$self->dbc()->sql_helper()->execute_simple(
        -SQL =>
          q/select distinct compara_analysis_id from compara_analysis 
  join genome_compara_analysis using (compara_analysis_id)
  where genome_id=? and method in ('BLASTZ_NET','LASTZ_NET','TRANSLATED_BLAT_NET', 'PROTEIN_TREES', 'ATAC')/,
        -PARAMS => [ $genome->dbID() ] ) } )
  {
    push @$comparas,
      $self->db()->get_GenomeComparaInfoAdaptor()->fetch_by_dbID($id);
  }
  $genome->compara($comparas);
  $genome->has_pan_compara();
  $genome->has_genome_alignments();
  $genome->has_peptide_compara();
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
  my ( $self, $genome ) = @_;
  $self->_fetch_databases($genome);
  $self->_fetch_organism($genome);
  $self->_fetch_assembly($genome);
  $self->_fetch_data_release($genome);
  $self->_fetch_variations($genome);
  $self->_fetch_annotations($genome);
  $self->_fetch_other_alignments($genome);
  $self->_fetch_comparas($genome);
  return;
}

=head2 _store_features
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Stores the features for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_features {
  my ( $self, $genome ) = @_;
  while ( my ( $type, $f ) = each %{ $genome->features() } ) {
    while ( my ( $analysis, $count ) = each %$f ) {
      $self->dbc()->sql_helper()->execute_update(
        -SQL =>
          q/insert into genome_feature(genome_id,type,analysis,count,genome_database_id)
		values(?,?,?,?,?)/,
        -PARAMS => [ $genome->dbID(), $type, $analysis, $count, $genome->{databases}->[0]->dbID ] );
    }
  }
  return;
}

=head2 _store_databases
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Stores the databases for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_databases {
  my ( $self, $genome ) = @_;
  # write current databases
  for my $database ( @{ $genome->databases() } ) {      
     # Clear out the old database
     my $dbia = $self->db()->get_DatabaseInfoAdaptor();
     $dbia->clear_genome_database($genome,$database);
     $dbia->store($database);
  }
  return;
}

=head2 _store_annotations
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Stores the annotations for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_annotations {
  my ( $self, $genome ) = @_;
  while ( my ( $type, $value ) = each %{ $genome->annotations() } ) {
    $self->dbc()->sql_helper()->execute_update(
      -SQL => q/insert into genome_annotation(genome_id,type,value,genome_database_id)
		values(?,?,?,?)/,
      -PARAMS => [ $genome->dbID(), $type, $value, $genome->{databases}->[0]->dbID ] );
  }
  return;
}

=head2 _store_variations
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Stores the variations for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_variations {
  my ( $self, $genome ) = @_;
  while ( my ( $type, $f ) = each %{ $genome->variations() } ) {
    while ( my ( $key, $count ) = each %$f ) {
      $self->dbc()->sql_helper()->execute_update(
        -SQL =>
          q/insert into genome_variation(genome_id,type,name,count,genome_database_id)
		values(?,?,?,?,?)/,
        -PARAMS => [ $genome->dbID(), $type, $key, $count, $genome->{databases}->[0]->dbID ] );
    }
  }
  return;
}

=head2 _store_alignments
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Stores the alignments for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_alignments {
  my ( $self, $genome ) = @_;
  while ( my ( $type, $f ) = each %{ $genome->other_alignments() } ) {
    while ( my ( $key, $count ) = each %$f ) {
      $self->dbc()->sql_helper()->execute_update(
        -SQL =>
          q/insert into genome_alignment(genome_id,type,name,count,genome_database_id)
		values(?,?,?,?,?)/,
        -PARAMS => [ $genome->dbID(), $type, $key, $count, $genome->{databases}->[0]->dbID ] );
    }
  }
  return;
}

=head2 _store_compara
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Stores the compara analyses for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_compara {
  my ( $self, $genome ) = @_;
  if ( defined $genome->compara() ) {
    for my $compara ( @{ $genome->compara() } ) {
      if ( !defined $compara->dbID() ) {
        $self->db()->get_GenomeComparaInfoAdaptor()->store($compara);
      }
      $self->dbc()->sql_helper()->execute_update(
        -SQL =>
q/insert into genome_compara_analysis(genome_id,compara_analysis_id) values(?,?)/,
        -PARAMS => [ $genome->dbID(), $compara->dbID() ] );
    }
  }
  return;

}


=head1 METHODS
=head2 clear_genome
  Arg        : Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Clear genome from the genome table and children tables
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub clear_genome {
  my ( $self, $genome ) = @_;
  $self->dbc()->sql_helper()->execute_update(-SQL=>q/delete from genome where genome_id=?/,
  -PARAMS=>[$genome->dbID()]);
  return;
}

my $base_genome_fetch_sql =
  q/select genome_id as dbID, division.name as division, genebuild, 
has_pan_compara, has_variations, has_peptide_compara, 
has_genome_alignments, has_synteny, has_other_alignments, 
assembly_id, data_release_id, organism_id
from genome join division using (division_id)/;

sub _get_base_sql {
  return $base_genome_fetch_sql;
}

sub _get_id_field {
  return 'genome_id';
}

sub _get_obj_class {
  return 'Bio::EnsEMBL::MetaData::GenomeInfo';
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

sub _organism_adaptor {
  my ($self) = @_;
  if ( !defined $self->{organism_adaptor} ) {
    $self->{organism_adaptor} =
      $self->db()->get_GenomeOrganismInfoAdaptor();
  }
  return $self->{organism_adaptor};
}

sub _assembly_adaptor {
  my ($self) = @_;
  if ( !defined $self->{assembly_adaptor} ) {
    $self->{assembly_adaptor} =
      $self->db()->get_GenomeAssemblyInfoAdaptor();
  }
  return $self->{assembly_adaptor};
}

1;
