
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

Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor

=head1 SYNOPSIS

my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_adaptor();
my $md = $gdba->fetch_by_name("arabidopsis_thaliana");

=head1 DESCRIPTION

Adaptor for storing and retrieving GenomeInfo objects from MySQL genome_info database

To start working with an adaptor:

# getting an adaptor
## adaptor for latest public EG release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_eg_adaptor();
## adaptor for specified public EG release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_eg_adaptor(21);
## manually specify a given database
my $dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
-USER=>'anonymous',
-PORT=>4157,
-HOST=>'mysql-eg-publicsql.ebi.ac.uk',
-DBNAME=>'genome_info_21');
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->new(-DBC=>$dbc);

To find genomes, use the fetch methods e.g.

# find a genome by name
my $genome = $gdba->fetch_by_name('arabidopsis_thaliana');

# find and iterate over all genomes
for my $genome (@{$gdba->fetch_all()}) {
	print $genome->name()."\n";
}

# find and iterate over all genomes from plants
for my $genome (@{$gdba->fetch_all_by_division('EnsemblPlants')}) {
	print $genome->name()."\n";
}

# find and iterate over all genomes with variation
for my $genome (@{$gdba->fetch_all_with_variation()}) {
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

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::MetaData::GenomeInfo;
use Scalar::Util qw(looks_like_number);
use Data::Dumper;
use List::MoreUtils qw/natatime/;
use Scalar::Util qw(looks_like_number);

=head1 METHODS

=head2 release
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
    $self->{data_release} = $release;
  }
  if ( !defined $self->{data_release} ) {
    # default to current Ensembl release
    $self->{data_release} =
      $self->db()->get_DataReleaseInfoAdaptor()
      ->fetch_current_ensembl_release();
  }
  if ( !defined $self->{data_release}->dbID() ) {
    $self->db()->get_DataReleaseInfoAdaptor()->store( $self->{data_release} );
  }
  return $self->{data_release};
}

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
  if ( !defined $genome->data_release() ) {
    $genome->data_release( $self->data_release() );
  }
  if ( !defined $genome->data_release()->dbID() ) {
    $self->db()->get_DataReleaseInfoAdaptor()->store( $genome->data_release() );
  }
  if ( !defined $genome->assembly() ) {
    throw("Genome must be associated with an assembly");
  }
  if ( !defined $genome->assembly()->dbID() ) {
    $self->db()->get_GenomeAssemblyInfoAdaptor()->store( $genome->assembly() );
  }
  if ( !defined $genome->dbID() ) {
    # find out if genome exists first
    my ($dbID) =
      @{
      $self->dbc()->sql_helper()->execute_simple(
        -SQL =>
"select genome_id from genome where data_release_id=? and assembly_id=?",
        -PARAMS =>
          [ $genome->data_release()->dbID(), $genome->assembly()->dbID() ] ) };

    if ( defined $dbID ) {
      $genome->dbID($dbID);
      $genome->adaptor($self);
    }
  }

  if ( defined $genome->dbID() ) {
    return $self->update($genome);
  }
  $self->db()->get_GenomeAssemblyInfoAdaptor()->store( $genome->assembly() );
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/insert into genome(division,
genebuild,dbname,species_id,has_pan_compara,has_variations,has_peptide_compara,
has_genome_alignments,has_synteny,has_other_alignments,assembly_id,organism_id,data_release_id)
		values(?,?,?,?,?,?,?,?,?,?,?,?,?)/,
    -PARAMS => [ $genome->division(),
                 $genome->genebuild(),
                 $genome->dbname(),
                 $genome->species_id(),
                 $genome->has_pan_compara(),
                 $genome->has_variations(),
                 $genome->has_peptide_compara(),
                 $genome->has_genome_alignments(),
                 $genome->has_synteny(),
                 $genome->has_other_alignments(),
                 $genome->assembly()->dbID(),
                 $genome->assembly()->organism()->dbID(),
                 $genome->data_release()->dbID() ],
    -CALLBACK => sub {
      my ( $sth, $dbh, $rv ) = @_;
      $genome->dbID( $dbh->{mysql_insertid} );
    } );
  $genome->adaptor($self);
  $self->_store_annotations($genome);
  $self->_store_features($genome);
  $self->_store_variations($genome);
  $self->_store_alignments($genome);
  $self->_store_compara($genome);
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
  if ( !defined $genome->dbID() ) {
    croak "Cannot update an object that has not already been stored";
  }
  $self->db()->get_GenomeAssemblyInfoAdaptor()->update( $genome->assembly() );
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/update genome set division=?,
genebuild=?,dbname=?,species_id=?,has_pan_compara=?,has_variations=?,has_peptide_compara=?,
has_genome_alignments=?,has_synteny=?,has_other_alignments=?,assembly_id=?,organism_id=?,data_release_id=? where genome_id=?/
    ,
    -PARAMS => [ $genome->division(),
                 $genome->genebuild(),
                 $genome->dbname(),
                 $genome->species_id(),
                 $genome->has_pan_compara(),
                 $genome->has_variations(),
                 $genome->has_peptide_compara(),
                 $genome->has_genome_alignments(),
                 $genome->has_synteny(),
                 $genome->has_other_alignments(),
                 $genome->assembly()->dbID(),
                 $genome->assembly()->organism()->dbID(),
                 $genome->data_release()->dbID(),
                 $genome->dbID() ] );
  $genome->adaptor($self);
  $self->_store_annotations($genome);
  $self->_store_features($genome);
  $self->_store_variations($genome);
  $self->_store_alignments($genome);
  $self->_store_compara($genome);
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
    -SQL => q/update genome g join genome_compara_analysis gc using (genome_id) 
	  join compara_analysis c using (compara_analysis_id) 
	  set g.has_peptide_compara=1 where c.division<>'EnsemblPan' and
	  c.method='PROTEIN_TREES'/
  );

  #has_pan_compara
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/update genome g join genome_compara_analysis gc using (genome_id) 
	  join compara_analysis c using (compara_analysis_id) 
	  set g.has_pan_compara=1 where c.division='EnsemblPan' and
	  c.method='PROTEIN_TREES'/
  );

  #has_genome_alignments
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/update genome g join genome_compara_analysis gc using (genome_id) 
	  join compara_analysis c using (compara_analysis_id) 
	  set g.has_genome_alignments=1 where c.method in 
	  ('TRANSLATED_BLAT_NET','LASTZ_NET','TBLAT','ATAC','BLASTZ_NET')/
  );

  #has_synteny
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/update genome g join genome_compara_analysis gc using (genome_id) 
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

  $self->dbc()->sql_helper()->execute_update(
                        -SQL => q/delete from genome_feature where genome_id=?/,
                        -PARAMS => [ $genome->dbID() ] );

  while ( my ( $type, $f ) = each %{ $genome->features() } ) {
    while ( my ( $analysis, $count ) = each %$f ) {
      $self->dbc()->sql_helper()->execute_update(
        -SQL => q/insert into genome_feature(genome_id,type,analysis,count)
		values(?,?,?,?)/,
        -PARAMS => [ $genome->dbID(), $type, $analysis, $count ] );
    }
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

  $self->dbc()->sql_helper()->execute_update(
                     -SQL => q/delete from genome_annotation where genome_id=?/,
                     -PARAMS => [ $genome->dbID() ] );

  while ( my ( $type, $count ) = each %{ $genome->annotations() } ) {
    $self->dbc()->sql_helper()->execute_update(
      -SQL => q/insert into genome_annotation(genome_id,type,count)
		values(?,?,?)/,
      -PARAMS => [ $genome->dbID(), $type, $count ] );
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

  $self->dbc()->sql_helper()->execute_update(
                      -SQL => q/delete from genome_variation where genome_id=?/,
                      -PARAMS => [ $genome->dbID() ] );

  while ( my ( $type, $f ) = each %{ $genome->variations() } ) {
    while ( my ( $key, $count ) = each %$f ) {
      $self->dbc()->sql_helper()->execute_update(
        -SQL => q/insert into genome_variation(genome_id,type,name,count)
		values(?,?,?,?)/,
        -PARAMS => [ $genome->dbID(), $type, $key, $count ] );
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

  $self->dbc()->sql_helper()->execute_update(
                      -SQL => q/delete from genome_alignment where genome_id=?/,
                      -PARAMS => [ $genome->dbID() ] );

  while ( my ( $type, $f ) = each %{ $genome->other_alignments() } ) {
    while ( my ( $key, $count ) = each %$f ) {
      $self->dbc()->sql_helper()->execute_update(
        -SQL => q/insert into genome_alignment(genome_id,type,name,count)
		values(?,?,?,?)/,
        -PARAMS => [ $genome->dbID(), $type, $key, $count ] );
    }
  }
  return;
}

sub _store_compara {
  my ( $self, $genome ) = @_;

  $self->dbc()->sql_helper()->execute_update(
               -SQL => q/delete from genome_compara_analysis where genome_id=?/,
               -PARAMS => [ $genome->dbID() ] );
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

=head2 list_divisions
  Description: Get list of all Ensembl Genomes divisions for which information is available
  Returntype : Arrayref of strings
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub list_divisions {
  my ($self) = @_;
  return $self->dbc()->sql_helper()
    ->execute_simple(
    -SQL => q/select distinct division from genome where division<>'Ensembl'/ );
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
  if ( ref($organism) eq 'Bio::EnsEMBL::MetaData::GenomeOrganismInfo' ) {
    $organism = $organism->dbID();
  }
  return _first_element(
       $self->_fetch_generic_with_args( { 'organism_id', $organism }, $keen ) );
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

sub fetch_by_assembly {
  my ( $self, $assembly, $keen ) = @_;
  if ( ref($assembly) eq 'Bio::EnsEMBL::MetaData::GenomeAssemblyInfo' ) {
    $assembly = $assembly->dbID();
  }
  return _first_element(
       $self->_fetch_generic_with_args( { 'assembly_id', $assembly }, $keen ) );
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
  if ( $id =~ m/\.[0-9]+$/ ) {
    return $self->fetch_all_by_sequence_accession_versioned( $id, $keen );
  }
  else {
    return $self->fetch_all_by_sequence_accession_unversioned( $id, $keen );
  }
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
  return
    $self->_fetch_generic(
    $self->_get_base_sql() .
' where genome_id in (select distinct(genome_id) from genome_sequence where acc like ? or name like ?)',
    [ $id . '.%', $id . '.%' ],
    $keen );
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
  return
    $self->_fetch_generic(
    $self->_get_base_sql() .
' where genome_id in (select distinct(genome_id) from genome_sequence where acc=? or name=?)',
    [ $id, $id ],
    $keen );
}

=head2 fetch_by_assembly_id
  Arg	     : INSDC assembly accession
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly ID (versioned or unversioned)
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_assembly_id {
  my ( $self, $id, $keen ) = @_;
  if ( $id =~ m/\.[0-9]+$/ ) {
    return $self->fetch_by_assembly_id_versioned( $id, $keen );
  }
  else {
    return $self->fetch_by_assembly_id_unversioned( $id, $keen );
  }
}

=head2 fetch_by_assembly_id_versioned
  Arg	     : INSDC assembly accession
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly ID
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_assembly_id_versioned {
  my ( $self, $id, $keen ) = @_;
  return _first_element(
             $self->_fetch_generic_with_args( { 'assembly_id', $id }, $keen ) );
}

=head2 fetch_by_assembly_id_unversioned
  Arg	     : INSDC assembly set chain (unversioned accession)
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly set chain
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_assembly_id_unversioned {
  my ( $self, $id, $keen ) = @_;
  return
    _first_element( $self->_fetch_generic(
                           $self->_get_base_sql() . ' where assembly_id like ?',
                           [ $id . '.%' ], $keen ) );
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
  return $self->_fetch_generic_with_args( { 'division', $division }, $keen );
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
  my $organism =
    $self->_first_element(
                  $self->_fetch_generic_with_args( { 'name', $name }, $keen ) );
}

=head2 fetch_any_by_name
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
  my $dba = $self->fetch_by_name( $name, $keen );
  if ( !defined $dba ) {
    $dba = $self->fetch_by_alias( $name, $keen );
  }
  return $dba;
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
  return
    $self->_fetch_generic(
          $self->_get_base_sql() . q/ where species REGEXP ? or name REGEXP ? /,
          [ $name, $name ], $keen );
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
  return
    _first_element( $self->_fetch_generic(
                        $self->_get_base_sql() .
                          q/ join genome_alias using (genome_id) where alias=?/,
                        [$name],
                        $keen ) );
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
  return $self->_fetch_generic_with_args( { 'has_variations' => '1' }, $keen );
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
  return $self->_fetch_generic_with_args( { 'has_peptide_compara' => '1' },
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
  return $self->_fetch_generic_with_args( { 'has_pan_compara' => '1' }, $keen );
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
  return $self->_fetch_generic_with_args( { 'has_genome_alignments' => '1' },
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
  return $self->_fetch_generic_with_args( { 'has_other_alignments' => '1' },
                                          $keen );
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
  croak
    "Cannot fetch variations for a GenomeInfo object that has not been stored"
    if !defined $genome->dbID();
  my $variations = {};
  $self->dbc()->sql_helper()->execute_no_return(
    -SQL => 'select type,name,count from genome_variation where genome_id=?',
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
  croak
    "Cannot fetch alignments for a GenomeInfo object that has not been stored"
    if !defined $genome->dbID();
  my $alignments = {};
  $self->dbc()->sql_helper()->execute_no_return(
    -SQL => 'select type,name,count from genome_alignment where genome_id=?',
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
  croak
    "Cannot fetch annotations for a GenomeInfo object that has not been stored"
    if !defined $genome->dbID();
  my $annotations = {};
  $self->dbc()->sql_helper()->execute_no_return(
    -SQL      => 'select type,count from genome_annotation where genome_id=?',
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
  croak
    "Cannot fetch features  for a GenomeInfo object that has not been stored"
    if !defined $genome->dbID();
  my $features = {};
  $self->dbc()->sql_helper()->execute_no_return(
    -SQL => 'select type,analysis,count from genome_feature where genome_id=?',
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
        -SQL => q/select distinct compara_analysis_id from compara_analysis 
  join genome_compara_analysis using (compara_analysis_id)
  where genome_id=? and method in ('BLASTZ_NET','LASTZ_NET','TRANSLATED_BLAT_NET', 'PROTEIN_TREES', 'ATAC')/,
        -PARAMS => [ $genome->dbID() ] ) } )
  {
    push @$comparas,
      $self->db()->get_GenomeComparaInfoAdaptor()->fetch_compara_by_dbID($id);
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
  if ( defined $genome->{assembly_id} ) {
    $genome->assembly( $self->db()->get_GenomeAssemblyInfoAdaptor()
                       ->fetch_by_dbID( $genome->{assembly_id} ) );
  }
  if ( defined $genome->{data_release_id} ) {
    $genome->data_release( $self->db()->get_DataReleaseInfoAdaptor()
                           ->fetch_by_dbID( $genome->{data_release_id} ) );
  }
  $self->_fetch_variations($genome);
  $self->_fetch_annotations($genome);
  $self->_fetch_other_alignments($genome);
  $self->_fetch_comparas($genome);
  return;
}

my $base_genome_fetch_sql =
  q/select genome_id as dbID, division, genebuild, dbname,species_id,
has_pan_compara, has_variations, has_peptide_compara, 
has_genome_alignments, has_synteny, has_other_alignments, 
assembly_id, data_release_id
from genome/;

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

1;
